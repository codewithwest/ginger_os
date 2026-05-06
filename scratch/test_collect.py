from pathlib import Path
import os

def _collect_files(root: Path):
    patterns = ["**/*.sh", "**/*.py", "**/*.md", "**/*.txt", "**/*.json"]       
    files = []
    skip_dirs = {".venv", ".git", ".snapshots", "sources", "logs", "build", "__pycache__", "Library", "PackageCache"}
    
    for pat in patterns:
        for p in root.glob(pat):
            if any(part in skip_dirs or part.startswith('.') for part in p.parts):
                continue
            files.append(p)
    return files

root = Path("/home/jonas/Documents/west/ginger_os")
files = _collect_files(root)
print(f"Total files: {len(files)}")
for f in files[:20]:
    print(f)
