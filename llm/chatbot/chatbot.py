"""chatbot.py
Provides a Retrieval‑Augmented Generation (RAG) chain that answers questions
using both the LFS book and the repository source files.

ChromaDB client is lazily initialized to avoid blocking server startup
when ChromaDB is not running.
"""

from langchain_classic.retrievers import EnsembleRetriever
from pathlib import Path

import chromadb
from langchain_chroma import Chroma
from langchain_classic.chains import RetrievalQA
from langchain_core.documents import Document
from .llm_config import get_embeddings, get_llm, CHROMA_HOST, CHROMA_PORT

BASE_DIR = Path(__file__).parents[2]
BOOK_COLLECTION = "lfs_book"
REPO_COLLECTION = "ginger_repo"

_embeddings = get_embeddings()
_client = None
book_vs = None
repo_vs = None
qa = None


def _get_client():
    global _client
    if _client is None:
        try:
            _client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
        except Exception:
            _client = None
    return _client


def _safe_load_chroma(collection_name, client=None):
    if client is None:
        client = _get_client()
    if client is None:
        return Chroma.from_documents(
            [
                Document(
                    page_content="ChromaDB unavailable.",
                    metadata={"source": "none"},
                )
            ]
        )
    try:
        return Chroma(client=client, collection_name=collection_name)
    except Exception as e:
        print(f"[chatbot] Error connecting to collection {collection_name}: {e}")
    return Chroma.from_documents(
        [
            Document(
                page_content="Index not yet initialized.",
                metadata={"source": "none"},
            )
        ]
    )


def _ensure_initialized():
    global book_vs, repo_vs, qa, _client
    if qa is not None:
        return
    _client = _get_client()
    book_vs = _safe_load_chroma(BOOK_COLLECTION, _client)
    repo_vs = _safe_load_chroma(REPO_COLLECTION, _client)
    book_retriever = book_vs.as_retriever(
        search_kwargs={"k": 3}, search_type="similarity"
    )
    repo_retriever = repo_vs.as_retriever(
        search_kwargs={"k": 3}, search_type="similarity"
    )
    retriever = EnsembleRetriever(
        retrievers=[book_retriever, repo_retriever], weights=[0.5, 0.5]
    )
    qa_local = RetrievalQA.from_chain_type(
        llm=get_llm(),
        retriever=retriever,
        return_source_documents=True,
    )
    qa = qa_local


merged = None


def answer(question: str):
    _ensure_initialized()
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
