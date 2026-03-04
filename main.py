# main.py

import json
import os
import tempfile
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from openai import OpenAI

app = FastAPI(title="Chinese Voice Translator")

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

@app.post("/translate")
async def translate_audio(file: UploadFile = File(...)):
    # 1) Save uploaded audio to a temp file
    try:
        suffix = os.path.splitext(file.filename or "")[1] or ".wav"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(await file.read())
            tmp_path = tmp.name
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error saving file: {e}")

    try:
        # 2) Transcribe audio to Chinese text
        with open(tmp_path, "rb") as audio_file:
            transcription = client.audio.transcriptions.create(
                model="gpt-4o-mini-transcribe",  # or "whisper-1"
                file=audio_file,
                language="zh",  # force Chinese
            )

        chinese_text = transcription.text

        # 3) Use GPT to translate + rewrite
        prompt = f"""
You are a bilingual Chinese-English assistant.

1. First, translate the following Chinese sentence(s) into natural English.
2. Then, rewrite the same Chinese text into correct, standard written Chinese
   (good grammar, punctuation, natural phrasing).

Return your answer in JSON with keys:
- english_translation
- improved_chinese

Chinese input:
{chinese_text}
        """

        completion = client.chat.completions.create(
            model="gpt-4o-mini",  # or "gpt-4o"
            messages=[
                {"role": "system", "content": "You are a precise translator."},
                {"role": "user", "content": prompt},
            ],
            response_format={"type": "json_object"},
        )

        result = json.loads(completion.choices[0].message.content)

        return JSONResponse(
            {
                "chinese_transcription": chinese_text,
                "english_translation": result.get("english_translation"),
                "improved_chinese": result.get("improved_chinese"),
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Processing error: {e}")
    finally:
        # Clean up temp file
        try:
            os.remove(tmp_path)
        except Exception:
            pass
