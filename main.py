# main.py

import json
import os
import tempfile
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

import jieba
import psycopg2
import psycopg2.extras
from agents import Agent, Runner, function_tool
from fastapi import BackgroundTasks, FastAPI, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from openai import OpenAI
from psycopg2.extras import Json
from pydantic import BaseModel

app = FastAPI(title="Chinese Voice Translator")
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


def get_conn():
    return psycopg2.connect(os.getenv("DATABASE_URL"))


def init_db():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS word_cache (
                    id         SERIAL PRIMARY KEY,
                    word       TEXT NOT NULL UNIQUE,
                    pinyin     TEXT,
                    english    TEXT NOT NULL,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS character_strokes (
                    character  TEXT PRIMARY KEY,
                    stroke_data JSONB NOT NULL,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """)
        conn.commit()


# ── word cache ────────────────────────────────────────────────────────────────

def get_cached_words(words: list[str]) -> dict[str, dict]:
    if not words:
        return {}
    with get_conn() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                "SELECT word, english, pinyin FROM word_cache WHERE word = ANY(%s)",
                (words,),
            )
            rows = cur.fetchall()
    return {row["word"]: dict(row) for row in rows}


def store_words(entries: list[dict]) -> None:
    with get_conn() as conn:
        with conn.cursor() as cur:
            psycopg2.extras.execute_batch(
                cur,
                "INSERT INTO word_cache (word, english, pinyin) VALUES (%(word)s, %(english)s, %(pinyin)s) ON CONFLICT (word) DO NOTHING",
                entries,
            )
        conn.commit()


# ── stroke cache ──────────────────────────────────────────────────────────────

def is_cjk(char: str) -> bool:
    cp = ord(char)
    return (0x4E00 <= cp <= 0x9FFF or
            0x3400 <= cp <= 0x4DBF or
            0x20000 <= cp <= 0x2A6DF)


def fetch_stroke_data_from_cdn(char: str) -> dict | None:
    encoded = urllib.parse.quote(char)
    url = f"https://cdn.jsdelivr.net/npm/hanzi-writer-data@latest/{encoded}.json"
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            return json.loads(resp.read())
    except Exception:
        return None


def get_cached_strokes(characters: list[str]) -> dict[str, dict]:
    if not characters:
        return {}
    with get_conn() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                "SELECT character, stroke_data FROM character_strokes WHERE character = ANY(%s)",
                (characters,),
            )
            rows = cur.fetchall()
    return {row["character"]: row["stroke_data"] for row in rows}


def store_strokes(entries: list[dict]) -> None:
    with get_conn() as conn:
        with conn.cursor() as cur:
            psycopg2.extras.execute_batch(
                cur,
                "INSERT INTO character_strokes (character, stroke_data) VALUES (%(character)s, %(stroke_data)s) ON CONFLICT (character) DO NOTHING",
                entries,
            )
        conn.commit()


def cache_stroke_data(words: list[str]) -> None:
    """Background task: fetch and store stroke data for all CJK characters in words."""
    all_chars = list({char for word in words for char in word if is_cjk(char)})
    if not all_chars:
        return
    cached = get_cached_strokes(all_chars)
    missing = [c for c in all_chars if c not in cached]
    if not missing:
        return
    new_entries = []
    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = {executor.submit(fetch_stroke_data_from_cdn, char): char for char in missing}
        for future in as_completed(futures):
            char = futures[future]
            data = future.result()
            if data:
                new_entries.append({"character": char, "stroke_data": Json(data)})
    if new_entries:
        store_strokes(new_entries)


# ── LLM helpers ───────────────────────────────────────────────────────────────

def segment_chinese(text: str) -> list[str]:
    return [w.strip() for w in jieba.cut(text) if w.strip()]


def _llm_translate_words(words: list[str]) -> list[dict]:
    if not words:
        return []
    prompt = f"""Translate each Chinese word below.
Return a JSON object with key "words" containing an array.
Each element must have: "word", "english", "pinyin" (with tone marks).

Words: {json.dumps(words, ensure_ascii=False)}"""
    completion = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are a precise Chinese-English dictionary. Return only valid JSON."},
            {"role": "user", "content": prompt},
        ],
        response_format={"type": "json_object"},
    )
    data = json.loads(completion.choices[0].message.content)
    return data.get("words", [])


def _llm_translate_sentence(chinese_text: str) -> str:
    completion = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are a precise translator. Return only valid JSON."},
            {"role": "user", "content": f'Translate this Chinese sentence into natural English. Return JSON with key "translation".\n\n{chinese_text}'},
        ],
        response_format={"type": "json_object"},
    )
    return json.loads(completion.choices[0].message.content).get("translation", "")


# ── agent tools ───────────────────────────────────────────────────────────────

class WordTranslation(BaseModel):
    word: str
    english: str
    pinyin: str


class WordEntry(BaseModel):
    word: str
    english: str
    pinyin: str
    from_cache: bool


class TranslationOutput(BaseModel):
    sentence_translation: str
    words: list[WordEntry]


@function_tool
def lookup_words(words: list[str]) -> dict:
    """Look up Chinese words in the persistent cache. Returns cached translations and a list of missing words."""
    cached = get_cached_words(words)
    missing = [w for w in words if w not in cached]
    return {"cached": cached, "missing": missing}


@function_tool
def translate_words(words: list[str]) -> list[dict]:
    """Translate Chinese words to English with pinyin tone marks. Use for words not found in the cache."""
    return _llm_translate_words(words)


@function_tool
def save_words(entries: list[WordTranslation]) -> dict:
    """Persist newly translated words to the cache database."""
    store_words([e.model_dump() for e in entries])
    return {"saved": len(entries)}


@function_tool
def translate_sentence(text: str) -> str:
    """Translate the full Chinese sentence into natural English."""
    return _llm_translate_sentence(text)


translation_agent = Agent(
    name="Chinese Translation Agent",
    instructions="""\
You are a Chinese language processing agent. You have received a transcribed Chinese sentence and its segmented words.

Assemble a complete translation result by following these steps:
1. Call `lookup_words` with all segmented words to find which are cached.
2. For words NOT in the cache, call `translate_words`, then call `save_words` to persist them.
3. Call `translate_sentence` to get a natural English translation of the full sentence.
4. Return your final structured output with the sentence translation and a per-word list.
   Mark each word from_cache=true if it came from the cache, false if freshly translated.

Steps 2 and 3 are independent — you may call them in any order.\
""",
    tools=[lookup_words, translate_words, save_words, translate_sentence],
    output_type=TranslationOutput,
    model="gpt-4o-mini",
)

init_db()


# ── endpoint ──────────────────────────────────────────────────────────────────

@app.post("/translate")
async def translate_audio(background_tasks: BackgroundTasks, file: UploadFile = File(...)):
    try:
        suffix = os.path.splitext(file.filename or "")[1] or ".m4a"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(await file.read())
            tmp_path = tmp.name
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error saving file: {e}")

    try:
        # 1. Transcribe (deterministic — requires file I/O)
        with open(tmp_path, "rb") as audio_file:
            transcription = client.audio.transcriptions.create(
                model="gpt-4o-mini-transcribe",
                file=audio_file,
                language="zh",
            )
        chinese_text = transcription.text

        # 2. Segment into words (deterministic)
        words = segment_chinese(chinese_text)

        # 3. Run agentic translation pipeline
        result = await Runner.run(
            translation_agent,
            f"Chinese sentence: {chinese_text}\n"
            f"Segmented words: {json.dumps(words, ensure_ascii=False)}",
        )
        output: TranslationOutput = result.final_output

        # 4. Cache stroke data in the background (non-blocking)
        background_tasks.add_task(cache_stroke_data, words)

        return JSONResponse({
            "chinese_transcription": chinese_text,
            "sentence_translation": output.sentence_translation,
            "words": [w.model_dump() for w in output.words],
        })

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Processing error: {e}")
    finally:
        try:
            os.remove(tmp_path)
        except Exception:
            pass
