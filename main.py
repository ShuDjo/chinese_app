# main.py

import asyncio
import json
import os
import re
import tempfile
import urllib.parse

import asyncpg
import httpx
import jieba
from fastapi import BackgroundTasks, FastAPI, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from pydantic import BaseModel

app = FastAPI(title="Chinese Voice Translator")

DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "")
GROQ_API_KEY     = os.getenv("GROQ_API_KEY", "")
JINA_API_KEY     = os.getenv("JINA_API_KEY", "")
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
        await conn.execute(
            "ALTER TABLE word_cache ADD COLUMN IF NOT EXISTS serbian TEXT"
        )
        try:
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS course_chunks (
                    id          SERIAL PRIMARY KEY,
                    source      TEXT NOT NULL,
                    page_num    INTEGER,
                    chunk_index INTEGER,
                    text        TEXT NOT NULL,
                    embedding   vector(1024),
                    created_at  TIMESTAMPTZ DEFAULT NOW()
                )
            """)
        except Exception:
            pass  # pgvector not yet installed — ingest.py will create it when run


# ── word cache ────────────────────────────────────────────────────────────────

async def get_cached_words(words: list[str]) -> dict[str, dict]:
    if not words:
        return {}
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT word, english, pinyin, serbian FROM word_cache WHERE word = ANY($1)",
            words,
        )
    return {row["word"]: dict(row) for row in rows}


async def store_words(entries: list[dict]) -> None:
    if not entries:
        return
    async with pool.acquire() as conn:
        await conn.executemany(
            "INSERT INTO word_cache (word, english, pinyin, serbian) VALUES ($1, $2, $3, $4) "
            "ON CONFLICT (word) DO NOTHING",
            [(e["word"], e["english"], e["pinyin"],
              cyrillic_to_latin(e["serbian"]) if e.get("serbian") else None) for e in entries],
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


# ── Serbian script helpers ────────────────────────────────────────────────────

_CYRILLIC_TO_LATIN = str.maketrans(
    'абвгдежзијклмнопрстуфхцАБВГДЕЖЗИЈКЛМНОПРСТУФХЦ',
    'abvgdežzijklmnoprstufhcABVGDEŽZIJKLMNOPRSTUFHC',
)
_CYRILLIC_DIGRAPHS = [
    ('љ', 'lj'), ('њ', 'nj'), ('џ', 'dž'), ('ђ', 'đ'), ('ћ', 'ć'), ('ш', 'š'), ('ч', 'č'), ('ж', 'ž'),
    ('Љ', 'Lj'), ('Њ', 'Nj'), ('Џ', 'Dž'), ('Ђ', 'Đ'), ('Ћ', 'Ć'), ('Ш', 'Š'), ('Ч', 'Č'), ('Ж', 'Ž'),
]

def cyrillic_to_latin(s: str) -> str:
    for cyrl, lat in _CYRILLIC_DIGRAPHS:
        s = s.replace(cyrl, lat)
    return s.translate(_CYRILLIC_TO_LATIN)


# ── LLM helpers ───────────────────────────────────────────────────────────────

def segment_chinese(text: str) -> list[str]:
    return [w.strip() for w in jieba.cut(text) if w.strip() and any(is_cjk(c) for c in w)]


async def _deepseek_chat(messages: list[dict], http: httpx.AsyncClient) -> str:
    """Send a chat request to DeepSeek and return the response content string."""
    resp = await http.post(
        "https://api.deepseek.com/chat/completions",
        headers={"Authorization": f"Bearer {DEEPSEEK_API_KEY}"},
        json={
            "model": "deepseek-chat",
            "messages": messages,
            "response_format": {"type": "json_object"},
        },
        timeout=60.0,
    )
    resp.raise_for_status()
    return resp.json()["choices"][0]["message"]["content"]


async def _translate_words(words: list[str]) -> list[dict]:
    if not words:
        return []
    prompt = f"""Translate each Chinese word below.
Return a JSON object with key "words" containing an array.
Each element must have: "word", "english", "pinyin" (with tone marks), "serbian" (Serbian translation).

Words: {json.dumps(words, ensure_ascii=False)}"""
    async with httpx.AsyncClient() as http:
        content = await _deepseek_chat([
            {"role": "system", "content": "You are a precise Chinese-English-Serbian dictionary. Return only valid JSON."},
            {"role": "user", "content": prompt},
        ], http)
    return json.loads(content).get("words", [])


async def _translate_sentence(text: str) -> str:
    async with httpx.AsyncClient() as http:
        content = await _deepseek_chat([
            {"role": "system", "content": "You are a precise translator. Return only valid JSON."},
            {"role": "user", "content": f'Translate this Chinese sentence into natural English. Return JSON with key "translation".\n\n{text}'},
        ], http)
    return json.loads(content).get("translation", "")


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
            audio_bytes = audio_file.read()
        async with httpx.AsyncClient() as http:
            resp = await http.post(
                "https://api.groq.com/openai/v1/audio/transcriptions",
                headers={"Authorization": f"Bearer {GROQ_API_KEY}"},
                data={"model": "whisper-large-v3-turbo", "language": "zh"},
                files={"file": (os.path.basename(tmp_path), audio_bytes, "audio/m4a")},
                timeout=60.0,
            )
            resp.raise_for_status()
        chinese_text = resp.json()["text"]
        if not any(is_cjk(c) for c in chinese_text):
            return JSONResponse({"chinese_transcription": "", "words": [], "error": "no_chinese_detected"})
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
    async with httpx.AsyncClient() as http:
        resp = await http.post(
            "https://api.jina.ai/v1/embeddings",
            headers={"Authorization": f"Bearer {JINA_API_KEY}"},
            json={"model": "jina-embeddings-v3", "input": [text]},
            timeout=30.0,
        )
        resp.raise_for_status()
    return resp.json()["data"][0]["embedding"]


async def _retrieve_chunks(query: str, k: int = 5, sources: list[str] | None = None) -> list[str]:
    embedding = await _embed(query)
    vec = _fmt_vector(embedding)
    async with pool.acquire() as conn:
        if sources:
            rows = await conn.fetch(
                f"SELECT text FROM course_chunks WHERE source = ANY($1) ORDER BY embedding <=> '{vec}'::vector LIMIT $2",
                sources, k,
            )
        else:
            rows = await conn.fetch(
                f"SELECT text FROM course_chunks ORDER BY embedding <=> '{vec}'::vector LIMIT $1",
                k,
            )
    return [row["text"] for row in rows]


# ── quiz endpoints ────────────────────────────────────────────────────────────

class QuizStartRequest(BaseModel):
    topic: str
    sources: list[str] | None = None


class QuizHistoryItem(BaseModel):
    question: str
    answer: str


class QuizSessionRequest(BaseModel):
    topic: str
    history: list[QuizHistoryItem]
    sources: list[str] | None = None
    language: str = "en"


def _history_text(history: list[QuizHistoryItem]) -> str:
    return "\n".join(f"Q: {h.question}\nA: {h.answer}" for h in history)


def _lesson_sort_key(source: str) -> tuple[int, int]:
    """Parse 'course1_10.pdf' → (1, 10) for correct numeric sort order."""
    nums = re.findall(r'\d+', source)
    if len(nums) >= 2:
        return (int(nums[0]), int(nums[1]))
    if len(nums) == 1:
        return (int(nums[0]), 0)
    return (0, 0)


async def _get_cumulative_sources(selected_source: str) -> list[str]:
    """Return all lesson sources up to and including selected_source, sorted by lesson order."""
    async with pool.acquire() as conn:
        rows = await conn.fetch("SELECT DISTINCT source FROM course_chunks")
    all_sources = [r["source"] for r in rows]

    sorted_sources = sorted(all_sources, key=_lesson_sort_key)

    if selected_source not in sorted_sources:
        return [selected_source]
    idx = sorted_sources.index(selected_source)
    return sorted_sources[:idx + 1]


async def _build_exam_context(topic: str, selected_source: str) -> str:
    """
    Build a two-section context for lesson-based exams:
    - Primary: chunks from the selected lesson (exam questions should focus here)
    - Background: chunks from all prior lessons (student already knows this)
    """
    all_up_to = await _get_cumulative_sources(selected_source)
    prior_sources = [s for s in all_up_to if s != selected_source]

    primary_chunks = await _retrieve_chunks(topic, k=6, sources=[selected_source])
    primary_section = "## Current Lesson Material (focus exam questions on this vocabulary and topics):\n" + "\n\n".join(primary_chunks)

    if not prior_sources:
        return primary_section

    background_chunks = await _retrieve_chunks(topic, k=3, sources=prior_sources)
    background_section = "## Previously Learned Material (student already knows this — treat as background knowledge, do not make it the focus):\n" + "\n\n".join(background_chunks)

    return primary_section + "\n\n" + background_section


@app.get("/quiz/lessons")
async def quiz_lessons():
    """Return all ingested lesson sources sorted by lesson order."""
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT source, MAX(created_at) AS added_at "
            "FROM course_chunks GROUP BY source"
        )

    sorted_rows = sorted(rows, key=lambda r: _lesson_sort_key(r["source"]))
    return JSONResponse({
        "lessons": [
            {"source": row["source"], "added_at": row["added_at"].isoformat()}
            for row in sorted_rows
        ]
    })


@app.post("/quiz/start")
async def quiz_start(req: QuizStartRequest):
    """Generate the first question for an exam session."""
    try:
        if req.sources and len(req.sources) == 1:
            context = await _build_exam_context(req.topic, req.sources[0])
        else:
            chunks = await _retrieve_chunks(req.topic, k=7, sources=req.sources)
            context = "\n\n".join(chunks)
    except Exception:
        context = ""

    try:
        async with httpx.AsyncClient() as http:
            content = await _deepseek_chat([
                {"role": "system", "content": (
                    "You are a Chinese oral examiner having a structured conversation with a student. "
                    "Use the lesson material ONLY to understand what vocabulary, grammar patterns, and topics the student has studied — "
                    "do NOT copy or quote sentences from the material. "
                    "Your job is to test whether the student can USE Chinese in real situations, not recite it. "
                    "\n\nRules:"
                    "\n- Ask ALL questions in Chinese only."
                    "\n- NEVER ask the student to translate a sentence. No '请翻译' tasks."
                    "\n- Ask short, natural conversational questions, like a real oral exam:"
                    "\n  • Personal questions using lesson vocabulary (e.g. if lesson covers jobs: 你做什么工作？你喜欢你的工作吗？)"
                    "\n  • Situational prompts (e.g. 如果你去餐厅，你怎么点菜？)"
                    "\n  • Opinion/preference questions (e.g. 你更喜欢...还是...？为什么？)"
                    "\n  • Describe-a-situation (e.g. 你能介绍一下你的家人吗？)"
                    "\n  • Simple role-play (e.g. 我是你的同事，你怎么向我介绍你自己？)"
                    "\n- Keep questions concise — one question at a time."
                    "\nReturn only valid JSON with key 'question'."
                )},
                {"role": "user", "content": f"""The student has studied the following lesson material. Use it to understand their vocabulary and grammar level:

{context}

Exam topic: {req.topic}

Start the oral examination with a natural opening question in Chinese."""},
            ], http)
        data = json.loads(content)
        return JSONResponse({"question": data.get("question", "")})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/quiz/next")
async def quiz_next(req: QuizSessionRequest):
    """Generate the next question based on the conversation so far."""
    try:
        if req.sources and len(req.sources) == 1:
            context = await _build_exam_context(req.topic, req.sources[0])
        else:
            chunks = await _retrieve_chunks(req.topic, k=7, sources=req.sources)
            context = "\n\n".join(chunks)
    except Exception:
        context = ""

    try:
        async with httpx.AsyncClient() as http:
            messages = [
                {"role": "system", "content": (
                    "You are a Chinese oral examiner continuing a structured conversation with a student. "
                    "Use the lesson material ONLY to understand what vocabulary and grammar the student knows — do NOT copy sentences from it. "
                    "\n\nRules:"
                    "\n- Ask ALL questions in Chinese only."
                    "\n- NEVER ask to translate a sentence. No '请翻译' tasks."
                    "\n- React naturally to the student's last answer:"
                    "\n  • If they answered well, follow up with a related or harder question"
                    "\n  • If they struggled, rephrase or simplify on the same theme"
                    "\n- Vary question types: personal questions, situational prompts, opinions, role-play."
                    "\n- Keep it conversational — one short question at a time."
                    "\nReturn only valid JSON with keys:"
                    "\n  'reaction': short Chinese acknowledgment of the previous answer (e.g. '好的！', '哦，很有意思。', '明白了。') — 1-5 words only, or null"
                    "\n  'question': the next question in Chinese"
                )},
                {"role": "user", "content": f"Lesson material (vocabulary/grammar reference only):\n\n{context}\n\nExam topic: {req.topic}"},
            ]
            for item in req.history:
                messages.append({"role": "assistant", "content": json.dumps({"question": item.question}, ensure_ascii=False)})
                messages.append({"role": "user", "content": item.answer})
            messages.append({"role": "user", "content": "Continue the oral examination with the next natural question in Chinese."})

            content = await _deepseek_chat(messages, http)
        data = json.loads(content)
        return JSONResponse({
            "question": data.get("question", ""),
            "reaction": data.get("reaction") or "",
        })
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/quiz/finish")
async def quiz_finish(req: QuizSessionRequest):
    """Evaluate the full quiz session and return overall feedback."""
    if not req.history:
        raise HTTPException(status_code=400, detail="No conversation to evaluate")

    if req.language == "sr-Cyrl":
        eval_lang_instruction = "Write ALL evaluation text in Serbian using Cyrillic script (ћирилица). "
    elif req.language == "sr-Latn":
        eval_lang_instruction = "Write ALL evaluation text in Serbian using Latin script (latinica). "
    else:
        eval_lang_instruction = "Write ALL evaluation text in English. "

    async with httpx.AsyncClient() as http:
        content = await _deepseek_chat([
            {"role": "system", "content": (
                "You are an experienced Chinese oral examiner evaluating a spoken conversation. "
                + eval_lang_instruction +
                "The student's answers are speech-to-text transcriptions — they will have no punctuation, "
                "may have run-on words, and spacing may be imperfect. "
                "IGNORE all formatting, punctuation, and spacing issues entirely. "
                "Evaluate ONLY the substance of communication: "
                "did the student understand the question, did they respond appropriately, "
                "did they use correct vocabulary and grammar for their level, "
                "did they express themselves clearly and naturally in Chinese. "
                "Never mention missing commas, spaces, or punctuation as mistakes. "
                "Return only valid JSON."
            )},
            {"role": "user", "content": f"""Evaluate this student's Chinese oral examination on: "{req.topic}"

The answers below are raw speech-to-text transcriptions. Judge the meaning and language ability, not the formatting.

Full conversation:
{_history_text(req.history)}

Return JSON with:
- "overall_score": integer 0-100 based on comprehension, vocabulary, grammar, and communication ability
- "summary": 2-3 sentence assessment focused on how well the student communicated in Chinese
- "strengths": array of 2-3 specific strengths (e.g. appropriate vocabulary, correct grammar pattern, natural responses, good comprehension)
- "improvements": array of 2-3 specific language areas to work on (e.g. wrong measure word, incorrect verb complement, limited vocabulary range)
- "exchanges": array of objects, one per Q&A pair, each with:
  - "question": the question asked
  - "answer": the student's answer
  - "score": integer 0-100 for that exchange
  - "mistake": null if the answer was communicatively correct, otherwise describe the actual language error (wrong word choice, incorrect grammar structure, misunderstood the question, etc.) — never mention punctuation or spacing"""},
        ], http)
    data = json.loads(content)
    return JSONResponse({
        "overall_score": data.get("overall_score", 0),
        "summary": data.get("summary", ""),
        "strengths": data.get("strengths", []),
        "improvements": data.get("improvements", []),
        "exchanges": data.get("exchanges", []),
    })


@app.post("/quiz/transcribe")
async def quiz_transcribe(file: UploadFile = File(...)):
    """Transcribe a quiz answer with auto language detection (no forced Chinese)."""
    try:
        suffix = os.path.splitext(file.filename or "")[1] or ".m4a"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(await file.read())
            tmp_path = tmp.name
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error saving file: {e}")

    try:
        with open(tmp_path, "rb") as audio_file:
            audio_bytes = audio_file.read()
        async with httpx.AsyncClient() as http:
            resp = await http.post(
                "https://api.groq.com/openai/v1/audio/transcriptions",
                headers={"Authorization": f"Bearer {GROQ_API_KEY}"},
                data={"model": "whisper-large-v3-turbo", "language": "zh"},
                files={"file": (os.path.basename(tmp_path), audio_bytes, "audio/m4a")},
                timeout=60.0,
            )
            resp.raise_for_status()
        return JSONResponse({"text": resp.json()["text"]})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Processing error: {e}")
    finally:
        try:
            os.remove(tmp_path)
        except Exception:
            pass


class CharacterLookupRequest(BaseModel):
    query: str
    input_type: str = "any"  # "english" | "serbian" | "pinyin" | "any"


@app.post("/character/lookup")
async def character_lookup(req: CharacterLookupRequest):
    """Look up a word from the local word_cache dictionary only."""
    query = req.query.strip()
    if not query:
        raise HTTPException(status_code=400, detail="Query is empty")

    like = f"%{query.lower()}%"
    async with pool.acquire() as conn:
        if req.input_type == "english":
            row = await conn.fetchrow(
                """SELECT word, pinyin, english, serbian FROM word_cache
                   WHERE word = $1 OR LOWER(english) ILIKE $2
                   LIMIT 1""",
                query, like,
            )
        elif req.input_type == "serbian":
            # Search both the original query and its transliterated form so
            # Cyrillic input matches Latin-stored values and vice versa
            like_alt = f"%{cyrillic_to_latin(query).lower()}%"
            row = await conn.fetchrow(
                """SELECT word, pinyin, english, serbian FROM word_cache
                   WHERE word = $1
                      OR LOWER(COALESCE(serbian, '')) ILIKE $2
                      OR LOWER(COALESCE(serbian, '')) ILIKE $3
                   LIMIT 1""",
                query, like, like_alt,
            )
        elif req.input_type == "pinyin":
            row = await conn.fetchrow(
                """SELECT word, pinyin, english, serbian FROM word_cache
                   WHERE word = $1 OR LOWER(pinyin) ILIKE $2
                   LIMIT 1""",
                query, like,
            )
        else:
            row = await conn.fetchrow(
                """SELECT word, pinyin, english, serbian FROM word_cache
                   WHERE word = $1
                      OR LOWER(english) ILIKE $2
                      OR LOWER(COALESCE(serbian, '')) ILIKE $2
                      OR LOWER(pinyin) ILIKE $2
                   LIMIT 1""",
                query, like,
            )

    if not row:
        raise HTTPException(status_code=404, detail="not_in_dictionary")

    return JSONResponse({
        "characters": row["word"],
        "pinyin":     row["pinyin"] or "",
        "english":    row["english"],
        "serbian":    row["serbian"] or "",
    })


class AiLookupRequest(BaseModel):
    query: str
    input_type: str = "english"  # "english" | "serbian" | "pinyin"


@app.post("/character/ai-lookup")
async def character_ai_lookup(req: AiLookupRequest):
    """Use AI to find a word and return its Chinese characters, pinyin, English and Serbian."""
    query = req.query.strip()
    if not query:
        raise HTTPException(status_code=400, detail="Query is empty")

    if req.input_type == "serbian":
        lang_hint = "Serbian"
    elif req.input_type == "pinyin":
        lang_hint = "pinyin"
    else:
        lang_hint = "English"

    try:
        async with httpx.AsyncClient() as http:
            content = await _deepseek_chat([
                {"role": "system", "content": (
                    "You are a Chinese-English-Serbian dictionary. "
                    "Given a word or phrase in any language, return its Chinese translation "
                    "along with pinyin, English meaning, and Serbian translation. "
                    "Return ONLY valid JSON with keys: word (Chinese characters), "
                    "pinyin (with tone marks), english (English translation), serbian (Serbian translation)."
                )},
                {"role": "user", "content": (
                    f'The user typed this {lang_hint} word/phrase: "{query}"\n'
                    "Return its Chinese translation as JSON."
                )},
            ], http)
        data = json.loads(content)
        if not data.get("word"):
            raise HTTPException(status_code=422, detail="Could not determine Chinese translation")
        return JSONResponse({
            "characters": data["word"],
            "pinyin":     data.get("pinyin", ""),
            "english":    data.get("english", ""),
            "serbian":    data.get("serbian", ""),
        })
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/character/random")
async def character_random():
    """Return a random word from the word_cache table."""
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT word, pinyin, english, serbian FROM word_cache ORDER BY RANDOM() LIMIT 1"
        )
    if not row:
        raise HTTPException(status_code=404, detail="No characters in database")

    serbian = row["serbian"] or ""

    # If Serbian is missing, generate it on the fly and cache it
    if not serbian:
        try:
            translations = await _translate_words([row["word"]])
            if translations:
                raw_serbian = translations[0].get("serbian", "") or ""
                serbian = cyrillic_to_latin(raw_serbian) if raw_serbian else ""
                if serbian:
                    async with pool.acquire() as conn:
                        await conn.execute(
                            "UPDATE word_cache SET serbian = $1 WHERE word = $2",
                            serbian, row["word"]
                        )
        except Exception:
            pass  # Fall through with empty Serbian if generation fails

    return JSONResponse({
        "characters": row["word"],
        "pinyin": row["pinyin"],
        "english": row["english"],
        "serbian": serbian,
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


class HintRequest(BaseModel):
    text: str


@app.post("/exam/hint")
async def exam_hint(req: HintRequest):
    """Translate an exam question to English without saving anything to the database."""
    translation = await _translate_sentence(req.text)
    return JSONResponse({"translation": translation})
