# main.py

import json
import os
import tempfile

import jieba
import psycopg2
import psycopg2.extras
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from openai import OpenAI

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
        conn.commit()


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


def segment_chinese(text: str) -> list[str]:
    return [w.strip() for w in jieba.cut(text) if w.strip()]


def translate_missing_words(words: list[str]) -> list[dict]:
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


def translate_sentence(chinese_text: str) -> str:
    completion = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are a precise translator. Return only valid JSON."},
            {"role": "user", "content": f'Translate this Chinese sentence into natural English. Return JSON with key "translation".\n\n{chinese_text}'},
        ],
        response_format={"type": "json_object"},
    )
    return json.loads(completion.choices[0].message.content).get("translation", "")


init_db()


@app.post("/translate")
async def translate_audio(file: UploadFile = File(...)):
    try:
        suffix = os.path.splitext(file.filename or "")[1] or ".m4a"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(await file.read())
            tmp_path = tmp.name
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error saving file: {e}")

    try:
        # 1. Transcribe
        with open(tmp_path, "rb") as audio_file:
            transcription = client.audio.transcriptions.create(
                model="gpt-4o-mini-transcribe",
                file=audio_file,
                language="zh",
            )
        chinese_text = transcription.text

        # 2. Segment into words
        words = segment_chinese(chinese_text)

        # 3. Batch DB lookup
        cached = get_cached_words(words)
        missing = [w for w in words if w not in cached]

        # 4. Translate missing words, store in DB
        new_entries = translate_missing_words(missing)
        if new_entries:
            store_words(new_entries)

        # 5. Merge all word data
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

        # 6. Full sentence translation
        sentence_translation = translate_sentence(chinese_text)

        return JSONResponse({
            "chinese_transcription": chinese_text,
            "sentence_translation": sentence_translation,
            "words": word_results,
        })

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Processing error: {e}")
    finally:
        try:
            os.remove(tmp_path)
        except Exception:
            pass
