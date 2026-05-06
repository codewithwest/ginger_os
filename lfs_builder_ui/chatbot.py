"""chatbot.py
Provides a Retrieval‑Augmented Generation (RAG) chain that answers questions
using both the LFS book and the repository source files.
"""

import os
from pathlib import Path

import chromadb
from langchain_chroma import Chroma
from langchain_classic.chains import RetrievalQA
from langchain_core.documents import Document
from .llm_config import get_embeddings, get_llm, CHROMA_HOST, CHROMA_PORT

# ---------------------------------------------------------------------------
# Load the two collections (book and repo).
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).parents[2]
BOOK_COLLECTION = "lfs_book"
REPO_COLLECTION = "ginger_repo"

# Use Ollama for local embeddings (same model as ingestion)
_embeddings = get_embeddings()
_client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)


def _safe_load_chroma(collection_name, client):
    """Connect to a Chroma collection or return an empty one if missing."""
    try:
        return Chroma(client=client, collection_name=collection_name)
    except Exception as e:
        print(f"[chatbot] Error connecting to collection {collection_name}: {e}")

    # Return a dummy empty index if missing or failed to load
    return Chroma.from_documents(
        [
            Document(
                page_content="Index not yet initialized.", metadata={"source": "none"}
            )
        ]
    )


# Connect to collections
book_vs = _safe_load_chroma(BOOK_COLLECTION, _client)
repo_vs = _safe_load_chroma(REPO_COLLECTION, _client)

# ---------------------------------------------------------------------------
# Build the RetrievalQA chain.
# ---------------------------------------------------------------------------
from langchain_classic.retrievers import EnsembleRetriever

# Create retrievers for both collections
book_retriever = book_vs.as_retriever(
    search_kwargs={"k": 3}, search_type="similarity"
)
repo_retriever = repo_vs.as_retriever(
    search_kwargs={"k": 3}, search_type="similarity"
)

# Ensemble retriever to search both book (theoretical) and repo (implementation)
retriever = EnsembleRetriever(
    retrievers=[book_retriever, repo_retriever], weights=[0.5, 0.5]
)

# Use OllamaLLM for local generation
qa = RetrievalQA.from_chain_type(
    llm=get_llm(),
    retriever=retriever,
    return_source_documents=True,
)

# Export the underlying store as ``merged`` (using repo as primary for compatibility)
merged = repo_vs


# Export a convenient function for the FastAPI endpoint.
def answer(question: str):
    """Return the answer and source snippets for *question*."""
    try:
        result = qa.invoke({"query": question})
        sources = []
        for doc in result.get("source_documents", []):
            sources.append(
                {
                    "page": doc.metadata.get("source", "unknown"),
                    "snippet": doc.page_content[:200],
                }
            )
        return {"answer": result.get("result", ""), "sources": sources}
    except Exception as e:
        return {
            "answer": f"I encountered an error while searching the knowledge base: {str(e)}",
            "sources": [],
        }
