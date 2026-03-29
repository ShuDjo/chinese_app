#!/usr/bin/env python3
"""
ingest.py — one-time script to load PDF course materials into the vector DB.

Usage:
    python ingest.py lesson1.pdf lesson2.pdf ...
    python ingest.py lessons/*.pdf
    python ingest.py lesson1.pdf --force   # re-ingest even if already stored
"""

import argparse
import os
import sys
from pathlib import Path

import fitz  # pymupdf
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

EMBED_MODEL = "text-embedding-3-small"
EMBED_DIM   = 1536
CHUNK_WORDS = 400   # target words per chunk
OVERLAP     = 50    # words of overlap between consecutive chunks


# ── database ──────────────────────────────────────────────────────────────────

def get_conn():
    return psycopg2.connect(os.getenv("DATABASE_URL"))


def init_table():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(f"""
                CREATE TABLE IF NOT EXISTS course_chunks (
                    id          SERIAL PRIMARY KEY,
                    source      TEXT NOT NULL,
                    page_num    INTEGER,
                    chunk_index INTEGER,
                    text        TEXT NOT NULL,
                    embedding   vector({EMBED_DIM}),
                    created_at  TIMESTAMPTZ DEFAULT NOW()
                )
            """)
            # HNSW index — works well even on small datasets, no config needed
            cur.execute("""
                CREATE INDEX IF NOT EXISTS course_chunks_embedding_idx
                ON course_chunks USING hnsw (embedding vector_cosine_ops)
            """)
        conn.commit()
    print("Table and index ready.")


# ── PDF parsing ───────────────────────────────────────────────────────────────

def extract_pages(pdf_path: str) -> list[tuple[int, str]]:
    """Return [(page_num, text), ...] for all non-empty pages."""
    doc = fitz.open(pdf_path)
    pages = []
    for i, page in enumerate(doc):
        text = page.get_text().strip()
        if text:
            pages.append((i + 1, text))
    return pages


def extract_chinese_only(text: str) -> str:
    """Keep only lines that contain at least one CJK character, discarding English/Serbian explanations."""
    result = []
    for line in text.splitlines():
        if any('\u4e00' <= ch <= '\u9fff' or '\u3400' <= ch <= '\u4dbf' for ch in line):
            stripped = line.strip()
            if stripped:
                result.append(stripped)
    return "\n".join(result)


# ── chunking ──────────────────────────────────────────────────────────────────

def chunk_text(text: str) -> list[str]:
    """
    Split text into overlapping word-count chunks.
    Each chunk is ~CHUNK_WORDS words with OVERLAP words shared with the next chunk.
    """
    words = text.split()
    chunks = []
    start = 0
    while start < len(words):
        end = min(start + CHUNK_WORDS, len(words))
        chunk = " ".join(words[start:end])
        if chunk.strip():
            chunks.append(chunk)
        if end == len(words):
            break
        start += CHUNK_WORDS - OVERLAP
    return chunks


# ── embeddings ────────────────────────────────────────────────────────────────

def embed_texts(texts: list[str]) -> list[list[float]]:
    """Embed texts in batches. OpenAI allows up to 2048 per request."""
    BATCH = 512
    embeddings = []
    for i in range(0, len(texts), BATCH):
        batch = texts[i : i + BATCH]
        response = client.embeddings.create(model=EMBED_MODEL, input=batch)
        embeddings.extend([r.embedding for r in response.data])
        print(f"  Embedded {min(i + BATCH, len(texts))}/{len(texts)} chunks...")
    return embeddings


def fmt_vector(embedding: list[float]) -> str:
    """Format a Python list as a pgvector literal: [0.1,0.2,...]"""
    return "[" + ",".join(f"{x:.8f}" for x in embedding) + "]"


# ── ingestion ─────────────────────────────────────────────────────────────────

def already_ingested(source: str) -> int:
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM course_chunks WHERE source = %s", (source,))
            return cur.fetchone()[0]


def delete_source(source: str):
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM course_chunks WHERE source = %s", (source,))
        conn.commit()


def clear_all_chunks():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM course_chunks")
        conn.commit()
    print("All course chunks deleted from the database.")


def store_rows(rows: list[dict]):
    with get_conn() as conn:
        with conn.cursor() as cur:
            psycopg2.extras.execute_batch(
                cur,
                """
                INSERT INTO course_chunks (source, page_num, chunk_index, text, embedding)
                VALUES (%(source)s, %(page_num)s, %(chunk_index)s, %(text)s, %(embedding)s::vector)
                """,
                rows,
            )
        conn.commit()


def ingest_pdf(pdf_path: str, force: bool = False):
    source = Path(pdf_path).name
    print(f"\n── {source} ──────────────────────────")

    existing = already_ingested(source)
    if existing > 0:
        if not force:
            print(f"  Already ingested ({existing} chunks). Pass --force to re-ingest.")
            return
        print(f"  Re-ingesting (removing {existing} existing chunks)...")
        delete_source(source)

    # 1. Extract text per page
    pages = extract_pages(pdf_path)
    print(f"  {len(pages)} pages with text")

    # 2. Extract Chinese-only text and chunk each page
    all_chunks = []
    for page_num, page_text in pages:
        chinese_text = extract_chinese_only(page_text)
        if chinese_text:
            for chunk in chunk_text(chinese_text):
                all_chunks.append({"page_num": page_num, "text": chunk})
    print(f"  {len(all_chunks)} chunks created (~{CHUNK_WORDS} words each)")

    if not all_chunks:
        print("  No text found — is this a scanned/image PDF?")
        return

    # 3. Embed
    texts = [c["text"] for c in all_chunks]
    embeddings = embed_texts(texts)

    # 4. Store
    rows = [
        {
            "source": source,
            "page_num": c["page_num"],
            "chunk_index": i,
            "text": c["text"],
            "embedding": fmt_vector(emb),
        }
        for i, (c, emb) in enumerate(zip(all_chunks, embeddings))
    ]
    store_rows(rows)
    print(f"  Stored {len(rows)} chunks. Done.")


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Ingest PDF course materials into pgvector")
    parser.add_argument("pdfs", nargs="+", help="PDF file paths to ingest")
    parser.add_argument("--force", action="store_true", help="Re-ingest files already in DB")
    parser.add_argument("--clear-all", action="store_true", help="Delete ALL existing chunks before ingesting")
    args = parser.parse_args()

    missing_env = [v for v in ("DATABASE_URL", "OPENAI_API_KEY") if not os.getenv(v)]
    if missing_env:
        print(f"Error: missing environment variables: {', '.join(missing_env)}", file=sys.stderr)
        print("Create a .env file or export them in your shell.", file=sys.stderr)
        sys.exit(1)

    init_table()

    if args.clear_all:
        clear_all_chunks()

    for pdf_path in args.pdfs:
        if not os.path.exists(pdf_path):
            print(f"File not found: {pdf_path}", file=sys.stderr)
            continue
        ingest_pdf(pdf_path, force=args.force)

    print("\nAll done.")


if __name__ == "__main__":
    main()
