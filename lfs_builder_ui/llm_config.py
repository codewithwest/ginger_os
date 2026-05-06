from langchain_ollama import OllamaEmbeddings, OllamaLLM
import chromadb.utils.embedding_functions as ef

# Configuration for Ollama
OLLAMA_BASE_URL = "http://localhost:11434"
EMBEDDING_MODEL = "nomic-embed-text-v2-moe:latest"
LLM_MODEL = "gemma4:31b-cloud"

# Configuration for ChromaDB Server
CHROMA_HOST = "localhost"
CHROMA_PORT = 18008


def get_embeddings():
    return OllamaEmbeddings(model=EMBEDDING_MODEL, base_url=OLLAMA_BASE_URL)


def get_chroma_embeddings():
    """Returns a Chroma-native embedding function for Ollama."""
    return ef.OllamaEmbeddingFunction(
        model_name=EMBEDDING_MODEL, url=f"{OLLAMA_BASE_URL}/api/embeddings"
    )


def get_llm():
    return OllamaLLM(model=LLM_MODEL, base_url=OLLAMA_BASE_URL, temperature=0.0)
