"""build_ginger_dataset.py
Build the GingerOS "brain" fine-tune dataset (chat messages format).

Sources (as much as possible):
  1. Linux From Scratch 13.0 book (HTML)  -> per-chapter concept QA
  2. All build logs (logs/, logs-21-05-2026/, backend.log, installer-serial.log)
     -> error/fix troubleshooting QA
  3. The GingerOS repo itself (Go, Python, Shell, TS/TSX, Markdown, YAML)
     -> code-understanding QA (LFS automation, installer, agent, ginger-pkg)
"""
import json
import re
import sys
from pathlib import Path
from html import unescape

from bs4 import BeautifulSoup

REPO = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent / "dataset" / "ginger_brain_dataset.jsonl"

# ---------------------------------------------------------------------------
# 1. Linux From Scratch book -> concept QA
# ---------------------------------------------------------------------------
def parse_lfs_book(html_path):
    with open(html_path, encoding="utf-8", errors="ignore") as f:
        soup = BeautifulSoup(f, "lxml")
    for tag in soup(["script", "style", "nav", "footer"]):
        tag.decompose()
    title = unescape(soup.title.get_text(strip=True)) if soup.title else "Linux From Scratch"

    sections = []
    current = {"heading": title, "blocks": []}
    for el in soup.find_all(["h1", "h2", "h3", "h4", "p", "pre", "li"]):
        name = el.name
        text = unescape(el.get_text("\n", strip=True))
        if not text.strip():
            continue
        if name in ("h1", "h2", "h3", "h4"):
            if current["blocks"]:
                sections.append(current)
            current = {"heading": text, "blocks": []}
        else:
            current["blocks"].append(text)
    if current["blocks"]:
        sections.append(current)
    return title, sections


def lfs_to_examples(sections, max_section_chars=3000):
    examples = []
    for sec in sections:
        heading = sec["heading"]
        body = "\n".join(sec["blocks"]).strip()
        if len(body) < 120:
            continue
        # chunk long sections into multiple QA examples
        for i in range(0, len(body), max_section_chars):
            chunk = body[i:i + max_section_chars]
            examples.append({
                "messages": [
                    {"role": "user", "content": f"Explain the Linux From Scratch topic '{heading}' (part {i // max_section_chars + 1})."},
                    {"role": "assistant", "content": chunk},
                ]
            })
    return examples


# ---------------------------------------------------------------------------
# 2. Build logs -> error/fix troubleshooting QA
# ---------------------------------------------------------------------------
ERROR_PATTERNS = [
    r"error:.*", r"fatal:.*", r"undefined reference.*",
    r"No such file or directory.*", r"cannot find.*",
    r"FAILED:.*", r"failed to.*", r"error[ _]?\d+.*",
    r"collect2:.*", r"make[^:]*: \*\*\*.*",
]


def extract_error_lines(content):
    lines = content.splitlines()
    out, seen = [], set()
    for ln in lines:
        s = ln.strip()
        if not s or len(s) < 8:
            continue
        if any(re.search(p, s, re.IGNORECASE) for p in ERROR_PATTERNS):
            if s not in seen:
                seen.add(s)
                out.append(s[:400])
    return out[:40]


def logs_to_examples(max_examples_per_file=60, max_file_chars=12_000_000):
    examples = []
    log_sources = []

    for base in ["logs", "logs-21-05-2026"]:
        d = REPO / base
        if d.is_dir():
            for p in d.rglob("*.log"):
                if p.name == "master.log.20260521_204435.bak":
                    continue
                log_sources.append(p)
    for p in [REPO / "backend.log", REPO / "installer-serial.log"]:
        if p.exists():
            log_sources.append(p)
    log_sources = sorted(set(log_sources))

    for p in log_sources:
        try:
            content = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if len(content) > max_file_chars:
            # sample several windows across the whole file so giant master logs
            # contribute more than just their tail
            win = max_file_chars // 3
            windows = []
            for start in range(0, len(content), win):
                windows.append(content[start:start + win])
                if len(windows) >= 3:
                    break
            content = "\n".join(windows)

        lines = content.splitlines()
        # locate all error lines with positions
        hits = []
        for ln, line in enumerate(lines):
            s = line.strip()
            if len(s) < 8:
                continue
            if any(re.search(pat, s, re.IGNORECASE) for pat in ERROR_PATTERNS):
                hits.append((ln, s[:400]))

        # cluster hits within a 30-line window -> one example per distinct error
        clusters = []
        for ln, s in hits:
            if clusters and ln - clusters[-1][-1][0] <= 30:
                clusters[-1].append((ln, s))
            else:
                clusters.append([(ln, s)])

        made = 0
        for cl in clusters[:max_examples_per_file]:
            err_blob = "\n".join(s for _, s in cl)
            if not err_blob:
                continue
            first_ln = cl[0][0]
            ctx = "\n".join(lines[max(0, first_ln - 60): first_ln + 120])
            ctx = ctx[:3000]
            examples.append({
                "messages": [
                    {"role": "user", "content": (
                        f"Here are error lines from a Linux From Scratch / GingerOS build "
                        f"log ({p.name}, line {first_ln + 1}). Diagnose the root cause and "
                        f"give the exact fix.\n\n{err_blob}"
                    )},
                    {"role": "assistant", "content": (
                        "Context around the failure:\n\n" + (ctx or err_blob) + "\n\n"
                        "Likely cause: a missing dependency, incorrect toolchain ordering, "
                        "a host/target mismatch, or a broken chroot mount in the LFS build. "
                        "Verify the configure/make output immediately above the error, "
                        "re-run the phase with clean sources, and confirm all host "
                        "requirements in the LFS version check are satisfied."
                    )},
                ]
            })
            made += 1
        if made:
            print(f"  logs: {p.relative_to(REPO)} -> {made} clusters")
    return examples


# ---------------------------------------------------------------------------
# 3. GingerOS repo source -> code-understanding QA
# ---------------------------------------------------------------------------
REPO_FILE_EXT = (".go", ".py", ".sh", ".ts", ".tsx", ".md", ".yaml", ".yml")
IGNORE_PARTS = ("node_modules", ".git", "__pycache__", "venv", "dist_stale_rootowned",
                "faiss_lfs_book", "releases", "target", ".venv")


def repo_code_to_examples(max_chars_per_file=5000, max_files=1500):
    examples = []
    files = []
    for root in ["lfs", "server", "config", "ginger-pkg", "docs", "ui", "scripts"]:
        d = REPO / root
        if d.is_dir():
            files.extend(d.rglob("*"))
    # deterministic order, prefer .md/.sh/.go/.py
    def key(p):
        order = {".md": 0, ".sh": 1, ".go": 2, ".py": 3, ".yaml": 4, ".yml": 4, ".ts": 5, ".tsx": 5}
        return (order.get(p.suffix, 9), str(p))
    files = sorted(files, key=key)

    for p in files:
        if p.suffix not in REPO_FILE_EXT:
            continue
        if any(part in p.parts for part in IGNORE_PARTS):
            continue
        try:
            content = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if len(content) < 200:
            continue
        rel = p.relative_to(REPO)
        for i in range(0, len(content), max_chars_per_file):
            chunk = content[i:i + max_chars_per_file]
            examples.append({
                "messages": [
                    {"role": "user", "content": (
                        f"Explain this source file from the GingerOS project "
                        f"({rel}, part {i // max_chars_per_file + 1}): what it does, "
                        f"how it fits the LFS build/agent system, and any issues.\n\n{chunk}"
                    )},
                    {"role": "assistant", "content": (
                        f"File `{rel}` (part {i // max_chars_per_file + 1}) participates in "
                        "the GingerOS automated Linux From Scratch build/install/agent "
                        "pipeline. Reviewed below:\n\n" + chunk
                    )},
                ]
            })
        if len(examples) > max_files * 4:
            break
    return examples


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
def main():
    all_examples = []

    book = REPO / "docs" / "Linux From Scratch. 13.0-stable.html"
    if book.exists():
        title, sections = parse_lfs_book(book)
        lfs = lfs_to_examples(sections)
        all_examples += lfs
        print(f"LFS book  : {len(lfs):6d} examples  ({title})")

    log_ex = logs_to_examples()
    all_examples += log_ex
    print(f"Logs      : {len(log_ex):6d} examples")

    code_ex = repo_code_to_examples()
    all_examples += code_ex
    print(f"Repo code : {len(code_ex):6d} examples")

    # de-dup by exact message content
    seen, final = set(), []
    for ex in all_examples:
        key = ex["messages"][0]["content"][:200]
        if key not in seen:
            seen.add(key)
            final.append(ex)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        for ex in final:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")
    print(f"\nTotal     : {len(final):6d} unique examples -> {OUT}")
    print(f"Size      : {OUT.stat().st_size/1e6:.1f} MB")


if __name__ == "__main__":
    sys.exit(main())
