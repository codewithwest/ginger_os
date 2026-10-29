# GingerOS Brain Model Fine-Tuning

Goal: an **8B brain model** that is both an LFS build genius and the best Ginger agent.
Trained with QLoRA via Unsloth on:

- **Linux From Scratch 13.0 book** (`docs/Linux From Scratch. 13.0-stable.html`) → 527 concept examples
- **All build logs** (`logs/`, `logs-21-05-2026/`, `backend.log`, `installer-serial.log`) → 77 error/fix troubleshooting examples
- **The GingerOS repo itself** (Go, Python, Shell, TS/TSX, MD, YAML) → 239 code-understanding examples
- Total: ~670 unique chat-message examples (1.7 MB JSONL)

## Files
| File | Purpose |
|------|---------|
| `build_ginger_dataset.py` | Builds `dataset/ginger_brain_dataset.jsonl` from book + logs + repo |
| `train_ginger_brain.py` | Unsloth QLoRA train (Qwen3-8B, fallback Qwen2.5-7B-Instruct), exports GGUF Q4_K_M |
| `Modelfile` | Ollama Modelfile for serving the GGUF on the brain node |
| `linux_lfs_finetune.ipynb` | Original manual Colab notebook (Qwen2.5-Coder-7B, r=16, no GGUF) |

## Usage
```bash
# 1. rebuild dataset after source changes
python3 build_ginger_dataset.py

# 2. train (GPU box / Colab with T4-L4-A100)
python3 train_ginger_brain.py --dataset dataset/ginger_brain_dataset.jsonl

# 3. serve on brain node
ollama create ginger-brain -f Modelfile
ollama run ginger-brain
```

## Deployment
- **Brain (8B)**: Qwen3-8B, LoRA r=32, 2 epochs, Q4_K_M GGUF → Ollama on the brain GPU box.
- **Edge (3B)**: fleet room nodes (i3/8GB, celeron) can use a smaller Qwen2.5-3B built from the same dataset.
