"""knowledge_ingest.py
Extract the Linux‑From‑Scratch HTML book, split it into overlapping text chunks,
create embeddings (using OpenAI by default – any LangChain‑compatible provider works),
and store the vectors in a local FAISS index.

Running this module as a script will (re)create the index under
``knowledge/faiss_lfs_book`` relative to the repository root.
"""

import os
import time
from pathlib import Path

from bs4 import BeautifulSoup
from langchain_text_splitters import RecursiveCharacterTextSplitter
import chromadb
from langchain_chroma import Chroma
from .llm_config import get_embeddings, CHROMA_HOST, CHROMA_PORT

# Configuration
HTML_PATH = Path(__file__).parents[1] / "docs" / "Linux From Scratch.12.4-stable.html"
COLLECTION_NAME = "lfs_book"


def _load_html(path: Path) -> str:
    """Return plain‑text with headings preserved for better retrieval."""
    with open(path, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")
        for tag in soup.find_all(["h1", "h2", "h3", "h4"]):
            tag.insert_before("\n" + tag.get_text() + "\n")
        return soup.get_text(separator="\n")


def ingest():
    """Create (or update) the Chroma collection for the LFS book."""
    # 1. Embeddings and Client setup
    embeddings = get_embeddings()
    client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)

    try:
        vectorstore = Chroma(
            client=client,
            collection_name=COLLECTION_NAME
        )
        print(f"[knowledge_ingest] Connected to Chroma at {CHROMA_HOST}:{CHROMA_PORT}")
    except Exception as e:
        print(f"[knowledge_ingest] Could not connect to Chroma server ({e}).")
        return

    # 2. Check if we should re-ingest (simplified)
    # Since it's a server, we can check if the collection has any data
    data = vectorstore.get()
    if data.get("ids"):
        print(
            f"[knowledge_ingest] Collection '{COLLECTION_NAME}' already has {len(data['ids'])} items. Skipping for now."
        )
        # In a real scenario, we'd check mtime or clear the collection if a full refresh is needed.
        return

    print(f"[knowledge_ingest] Processing LFS book: {HTML_PATH.name}...")
    raw_text = _load_html(HTML_PATH)

    splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
    docs = splitter.create_documents([raw_text])

    print(f"[knowledge_ingest] Created {len(docs)} chunks. Generating embeddings...")

    # Batch processing for embeddings
    batch_size = 50
    for i in range(0, len(docs), batch_size):
        batch = docs[i : i + batch_size]
        vectorstore.add_documents(batch)

        processed = min(i + batch_size, len(docs))
        print(
            f"  Embedding: {processed}/{len(docs)} ({(processed / len(docs) * 100):.1f}%)",
            end="\r",
        )

    print(f"\n[knowledge_ingest] Successfully updated collection '{COLLECTION_NAME}'")


if __name__ == "__main__":
    ingest()
