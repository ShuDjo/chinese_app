# main.py

import asyncio
import json
import os
import tempfile
import urllib.parse

import asyncpg
import httpx
import jieba
from fastapi import BackgroundTasks, FastAPI, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from openai import AsyncOpenAI
from pydantic import BaseModel

app = FastAPI(title="Chinese Voice Translator")
client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))
pool: asyncpg.Pool | None = None


@app.on_event("startup")
async def startup():
    global pool

    async def init_conn(conn):
        await conn.set_type_codec(
            "jsonb",
            encoder=json.dumps,
            decoder=json.loads,
            schema="pg_catalog",
        )

    pool = await asyncpg.create_pool(
        os.getenv("DATABASE_URL"),
        init=init_conn,
        ssl="require",
        min_size=2,
        max_size=10,
    )

    async with pool.acquire() as conn:
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS word_cache (
                id         SERIAL PRIMARY KEY,
                word       TEXT NOT NULL UNIQUE,
                pinyin     TEXT,
                english    TEXT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
        """)
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS character_strokes (
                character   TEXT PRIMARY KEY,
                stroke_data JSONB NOT NULL,
                created_at  TIMESTAMPTZ DEFAULT NOW()
            )
        """)


# ── word cache ────────────────────────────────────────────────────────────────

async def get_cached_words(words: list[str]) -> dict[str, dict]:
    if not words:
        return {}
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT word, english, pinyin FROM word_cache WHERE word = ANY($1)",
            words,
        )
    return {row["word"]: dict(row) for row in rows}


async def store_words(entries: list[dict]) -> None:
    if not entries:
        return
    async with pool.acquire() as conn:
        await conn.executemany(
            "INSERT INTO word_cache (word, english, pinyin) VALUES ($1, $2, $3) "
            "ON CONFLICT (word) DO NOTHING",
            [(e["word"], e["english"], e["pinyin"]) for e in entries],
        )


# ── stroke cache ──────────────────────────────────────────────────────────────

def is_cjk(char: str) -> bool:
    cp = ord(char)
    return (0x4E00 <= cp <= 0x9FFF or
            0x3400 <= cp <= 0x4DBF or
            0x20000 <= cp <= 0x2A6DF)


async def get_cached_strokes(characters: list[str]) -> dict[str, dict]:
    if not characters:
        return {}
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT character, stroke_data FROM character_strokes WHERE character = ANY($1)",
            characters,
        )
    return {row["character"]: row["stroke_data"] for row in rows}


async def store_strokes(entries: list[dict]) -> None:
    if not entries:
        return
    async with pool.acquire() as conn:
        await conn.executemany(
            "INSERT INTO character_strokes (character, stroke_data) VALUES ($1, $2) "
            "ON CONFLICT (character) DO NOTHING",
            [(e["character"], e["stroke_data"]) for e in entries],
        )


async def _fetch_stroke_cdn(char: str, http: httpx.AsyncClient) -> tuple[str, dict | None]:
    url = f"https://cdn.jsdelivr.net/npm/hanzi-writer-data@latest/{urllib.parse.quote(char)}.json"
    try:
        resp = await http.get(url, timeout=5.0)
        resp.raise_for_status()
        return char, resp.json()
    except Exception:
        return char, None


async def cache_stroke_data(words: list[str]) -> None:
    all_chars = list({char for word in words for char in word if is_cjk(char)})
    if not all_chars:
        return
    cached = await get_cached_strokes(all_chars)
    missing = [c for c in all_chars if c not in cached]
    if not missing:
        return
    async with httpx.AsyncClient() as http:
        results = await asyncio.gather(*[_fetch_stroke_cdn(c, http) for c in missing])
    new_entries = [{"character": char, "stroke_data": data} for char, data in results if data]
    await store_strokes(new_entries)


# ── LLM helpers ───────────────────────────────────────────────────────────────

def segment_chinese(text: str) -> list[str]:
    return [w.strip() for w in jieba.cut(text) if w.strip()]


async def _translate_words(words: list[str]) -> list[dict]:
    if not words:
        return []
    prompt = f"""Translate each Chinese word below.
Return a JSON object with key "words" containing an array.
Each element must have: "word", "english", "pinyin" (with tone marks).

Words: {json.dumps(words, ensure_ascii=False)}"""
    completion = await client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are a precise Chinese-English dictionary. Return only valid JSON."},
            {"role": "user", "content": prompt},
        ],
        response_format={"type": "json_object"},
    )
    return json.loads(completion.choices[0].message.content).get("words", [])


async def _translate_sentence(text: str) -> str:
    completion = await client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are a precise translator. Return only valid JSON."},
            {"role": "user", "content": f'Translate this Chinese sentence into natural English. Return JSON with key "translation".\n\n{text}'},
        ],
        response_format={"type": "json_object"},
    )
    return json.loads(completion.choices[0].message.content).get("translation", "")


# ── endpoints ─────────────────────────────────────────────────────────────────

@app.post("/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    """Transcribe audio and translate words. No DB writes yet."""
    try:
        suffix = os.path.splitext(file.filename or "")[1] or ".m4a"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(await file.read())
            tmp_path = tmp.name
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error saving file: {e}")

    try:
        with open(tmp_path, "rb") as audio_file:
            transcription = await client.audio.transcriptions.create(
                model="gpt-4o-mini-transcribe",
                file=audio_file,
                language="zh",
            )
        chinese_text = transcription.text
        words = segment_chinese(chinese_text)

        # Look up cache and translate missing — read-only, no DB writes yet
        cached = await get_cached_words(words)
        missing = [w for w in words if w not in cached]
        new_entries = await _translate_words(missing)

        all_words = {**cached, **{e["word"]: e for e in new_entries}}
        word_results = [
            {
                "word": w,
                "english": all_words.get(w, {}).get("english", ""),
                "pinyin": all_words.get(w, {}).get("pinyin", ""),
                "from_cache": w in cached,
            }
            for w in words
        ]

        return JSONResponse({
            "chinese_transcription": chinese_text,
            "words": word_results,
        })

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Processing error: {e}")
    finally:
        try:
            os.remove(tmp_path)
        except Exception:
            pass


# ── RAG helpers ───────────────────────────────────────────────────────────────

def _fmt_vector(embedding: list[float]) -> str:
    return "[" + ",".join(f"{x:.8f}" for x in embedding) + "]"


async def _embed(text: str) -> list[float]:
    response = await client.embeddings.create(
        model="text-embedding-3-small",
        input=text,
    )
    return response.data[0].embedding


async def _retrieve_chunks(query: str, k: int = 5) -> list[str]:
    embedding = await _embed(query)
    vec = _fmt_vector(embedding)
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            f"SELECT text FROM course_chunks ORDER BY embedding <=> '{vec}'::vector LIMIT $1",
            k,
        )
    return [row["text"] for row in rows]


# ── quiz endpoints ─────────────────────────────────────────────────────────────

class QuizRequest(BaseModel):
    topic: str | None = None


@app.post("/quiz/question")
async def quiz_question(req: QuizRequest):
    query = req.topic or "Chinese language vocabulary grammar sentence patterns"
    chunks = await _retrieve_chunks(query, k=5)
    context = "\n\n---\n\n".join(chunks)

    completion = await client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are a Chinese language teacher creating quiz questions. Return only valid JSON."},
            {"role": "user", "content": f"""Based on this course material, create ONE quiz question to test the student.
The question can test vocabulary, grammar, translation, or comprehension.
Be specific and grounded in the material provided.
Return JSON with keys: "question" (the question text), "type" (vocabulary/grammar/translation/comprehension).

Course material:
{context}"""},
        ],
        response_format={"type": "json_object"},
    )
    data = json.loads(completion.choices[0].message.content)
    return JSONResponse({
        "question": data.get("question", ""),
        "type": data.get("type", ""),
    })


class EvaluateRequest(BaseModel):
    question: str
    answer: str


@app.post("/quiz/evaluate")
async def quiz_evaluate(req: EvaluateRequest):
    chunks = await _retrieve_chunks(req.question, k=5)
    context = "\n\n---\n\n".join(chunks)

    completion = await client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are a Chinese language teacher evaluating a student's answer. Return only valid JSON."},
            {"role": "user", "content": f"""Evaluate the student's answer based on the course material.

Question: {req.question}
Student's answer: {req.answer}

Course material:
{context}

Return JSON with:
- "score": integer 0-100
- "correct": true if score >= 70, false otherwise
- "feedback": brief, encouraging explanation of what was right or wrong
- "correct_answer": the ideal answer according to the course material"""},
        ],
        response_format={"type": "json_object"},
    )
    data = json.loads(completion.choices[0].message.content)
    return JSONResponse({
        "score": data.get("score", 0),
        "correct": data.get("correct", False),
        "feedback": data.get("feedback", ""),
        "correct_answer": data.get("correct_answer", ""),
    })


class WordData(BaseModel):
    word: str
    english: str
    pinyin: str


class TranslateRequest(BaseModel):
    text: str
    words: list[WordData]


@app.post("/translate")
async def translate_text(req: TranslateRequest, background_tasks: BackgroundTasks):
    """On Accept: save words to DB, translate sentence, cache strokes."""
    try:
        # Save words that weren't already in cache
        await store_words([w.model_dump() for w in req.words])

        sentence_translation = await _translate_sentence(req.text)

        word_list = [w.word for w in req.words]
        background_tasks.add_task(cache_stroke_data, word_list)

        return JSONResponse({"sentence_translation": sentence_translation})

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Processing error: {e}")
