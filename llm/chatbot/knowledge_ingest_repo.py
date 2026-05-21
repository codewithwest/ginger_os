"""knowledge_ingest_repo.py
Index every Bash script, Python file and Markdown document in the repository.
"""

import ast
from pathlib import Path


# Updated import path for RecursiveCharacterTextSplitter in newer LangChain versions
from langchain_text_splitters import RecursiveCharacterTextSplitter

# Use Chroma for local embeddings
import chromadb
from langchain_chroma import Chroma
from langchain_core.documents import Document
from .llm_config import get_embeddings, CHROMA_HOST, CHROMA_PORT

REPO_ROOT = Path(__file__).parents[1]
COLLECTION_NAME = "ginger_repo"


def _analyze_python_structure(path: Path, content: str):
    """Extract functions and classes to create a structural map of the file.

    This acts as a 'Merkle-like' summary of the code, allowing the agent to
    understand the hierarchy before diving into the implementation details.
    """
    nodes = []
    try:
        tree = ast.parse(content)
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                nodes.append(
                    Document(
                        page_content=f"Function: {node.name}\nArgs: {[arg.arg for arg in node.args.args]}",
                        metadata={
                            "source": str(path),
                            "type": "structure",
                            "node": "function",
                            "name": node.name,
                        },
                    )
                )
            elif isinstance(node, ast.ClassDef):
                nodes.append(
                    Document(
                        page_content=f"Class: {node.name}",
                        metadata={
                            "source": str(path),
                            "type": "structure",
                            "node": "class",
                            "name": node.name,
                        },
                    )
                )
    except Exception as e:
        print(f"  [ast] Could not parse {path.name}: {e}")
    return nodes


def _collect_files(root: Path):
    """Collect source files while skipping hidden and irrelevant directories."""
    patterns = ["**/*.sh", "**/*.py", "**/*.md", "**/*.txt", "**/*.json"]
    files: list[Path] = []

    # Directories to skip entirely
    skip_dirs = {
        ".venv",
        ".git",
        ".snapshots",
        "sources",
        "logs",
        "build",
        "__pycache__",
        "Library",
        "PackageCache",
    }

    for pat in patterns:
        for p in root.glob(pat):
            # Skip if any part of the path is in skip_dirs or starts with a dot
            if any(part in skip_dirs or part.startswith(".") for part in p.parts):
                continue
            files.append(p)
    return files


def ingest():
    # 1. Collect files
    all_files = _collect_files(REPO_ROOT)

    # 2. Embeddings and Client setup
    embeddings = get_embeddings()
    client = chromadb.HttpClient(
        host=CHROMA_HOST or "localhost", port=CHROMA_PORT or 18008
    )

    try:
        # Initialize Chroma with HttpClient, but let it handle embeddings locally
        vectorstore = Chroma(client=client, collection_name=COLLECTION_NAME)

        # Get list of already indexed files from metadata
        data = vectorstore.get()
        indexed_files = {m.get("source") for m in data.get("metadatas", []) if m}
        print(
            f"[knowledge_ingest_repo] Connected to Chroma at {CHROMA_HOST}:{CHROMA_PORT}. Indexed files: {len(indexed_files)}"
        )
    except Exception as e:
        print(f"[knowledge_ingest_repo] Could not connect to Chroma server ({e}).")
        return

    # 3. Filter for new/changed files
    files_to_process = []
    for p in all_files:
        p_str = str(p)
        if any(skip in p_str for skip in (".venv", "Library", "PackageCache")):
            continue
        # Only add if not already indexed
        if p_str not in indexed_files:
            files_to_process.append(p)

    if not files_to_process:
        print("[knowledge_ingest_repo] No new files to index.")
        return

    print(f"[knowledge_ingest_repo] Indexing {len(files_to_process)} new files...")
    # for p in files_to_process: print(f"  - {p}")

    # 4. Read files and extract structure (AST)
    structural_docs = []
    content_docs = []

    for i, p in enumerate(files_to_process, 1):
        try:
            with open(p, "r", encoding="utf-8", errors="ignore") as f:
                text = f.read()

            # If it's a Python file, add structural nodes (AST)
            if p.suffix == ".py":
                struct_nodes = _analyze_python_structure(p, text)
                structural_docs.extend(struct_nodes)
            else:
                # For non-Python files, we keep the content
                content_docs.append(
                    Document(
                        page_content=text,
                        metadata={"source": str(p), "type": "content"},
                    )
                )

            if i % 10 == 0 or i == len(files_to_process):
                print(
                    f"  Reading files: {i}/{len(files_to_process)} ({(i / len(files_to_process) * 100):.1f}%)",
                    end="\r",
                )
        except Exception as e:
            print(f"\nSkipping {p} due to error: {e}")

    print("\n[knowledge_ingest_repo] Reading complete.")

    # 5. Process Documents: Split content, keep structure atomic
    final_docs = []

    # Structural nodes are already small summaries; we DON'T split them.
    final_docs.extend(structural_docs)

    # Split large content files
    if content_docs:
        print("[knowledge_ingest_repo] Splitting content documents...")
        splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=150)
        content_chunks = splitter.split_documents(content_docs)
        final_docs.extend(content_chunks)

    if not final_docs:
        print("[knowledge_ingest_repo] No new content to index.")
        return

    print(f"[knowledge_ingest_repo] Creating embeddings for {len(final_docs)} nodes...")

    # 6. Batch processing for embeddings
    batch_size = 50
    for i in range(0, len(final_docs), batch_size):
        batch = final_docs[i : i + batch_size]
        vectorstore.add_documents(batch)

        processed = min(i + batch_size, len(final_docs))
        print(
            f"  Embedding: {processed}/{len(final_docs)} ({(processed / len(final_docs) * 100):.1f}%)",
            end="\r",
        )

    print(
        f"\n[knowledge_ingest_repo] Successfully updated collection '{COLLECTION_NAME}'"
    )


if __name__ == "__main__":
    ingest()
