"""train_ginger_brain.py
Unsloth QLoRA fine-tune of the GingerOS 8B "brain" model.

Base model : Qwen3-8B (fallback Qwen2.5-7B-Instruct) -- 8B brain model
Dataset    : llm/finetuning/dataset/ginger_brain_dataset.jsonl
Output     : merged model + GGUF Q4_K_M for Ollama (deploy to brain node)

Run (GPU box with CUDA):
    pip install unsloth
    python3 train_ginger_brain.py --dataset dataset/ginger_brain_dataset.jsonl

Colab (T4/L4/A100) -- paste cells 1..N, or:
    python3 train_ginger_brain.py --colab
"""
import argparse
import json

import torch
from datasets import load_dataset
from unsloth import FastLanguageModel, is_bfloat16_supported
from trl import SFTTrainer, SFTConfig

MODEL = "Qwen/Qwen3-8B"
FALLBACK = "Qwen/Qwen2.5-7B-Instruct"
MAX_SEQ = 4096
LORA_R = 32
LORA_ALPHA = 32


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", default="dataset/ginger_brain_dataset.jsonl")
    ap.add_argument("--epochs", type=int, default=2)
    ap.add_argument("--batch", type=int, default=2)
    ap.add_argument("--grad-accum", type=int, default=4)
    ap.add_argument("--lr", type=float, default=2e-4)
    ap.add_argument("--out", default="ginger-brain-lora")
    ap.add_argument("--gguf", default="ginger-brain-q4_k_m.gguf")
    ap.add_argument("--no-gguf", action="store_true")
    return ap.parse_args()


def load_model():
    try:
        model, tokenizer = FastLanguageModel.from_pretrained(
            model_name=MODEL,
            max_seq_length=MAX_SEQ,
            dtype=None,
            load_in_4bit=True,
        )
    except Exception as e:  # noqa: BLE001
        print(f"{MODEL} failed ({e}); falling back to {FALLBACK}")
        model, tokenizer = FastLanguageModel.from_pretrained(
            model_name=FALLBACK,
            max_seq_length=MAX_SEQ,
            dtype=None,
            load_in_4bit=True,
        )
    model = FastLanguageModel.get_peft_model(
        model,
        r=LORA_R,
        target_modules=[
            "q_proj", "k_proj", "v_proj", "o_proj",
            "gate_proj", "up_proj", "down_proj",
        ],
        lora_alpha=LORA_ALPHA,
        lora_dropout=0,
        bias="none",
        use_gradient_checkpointing="unsloth",
        random_state=3407,
        use_rslora=True,
        loftq_config=None,
    )
    return model, tokenizer


def format_chat(example, tokenizer):
    messages = example["messages"]
    text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=False)
    return {"text": text}


def main():
    args = parse_args()
    model, tokenizer = load_model()

    ds = load_dataset("json", data_files=args.dataset, split="train")
    ds = ds.map(lambda ex: format_chat(ex, tokenizer), remove_columns=["messages"])
    print(f"dataset: {len(ds)} rows, sample text:\n{ds[0]['text'][:300]}")

    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=ds,
        dataset_text_field="text",
        max_seq_length=MAX_SEQ,
        packing=True,
        args=SFTConfig(
            per_device_train_batch_size=args.batch,
            gradient_accumulation_steps=args.grad_accum,
            warmup_steps=10,
            num_train_epochs=args.epochs,
            learning_rate=args.lr,
            fp16=not is_bfloat16_supported(),
            bf16=is_bfloat16_supported(),
            logging_steps=1,
            optim="adamw_8bit",
            weight_decay=0.01,
            lr_scheduler_type="linear",
            seed=3407,
            output_dir=args.out,
            report_to="none",
        ),
    )

    trainer.train()
    model.save_pretrained(args.out)
    tokenizer.save_pretrained(args.out)
    print(f"LoRA adapters saved -> {args.out}")

    # test inference before export
    FastLanguageModel.for_inference(model)
    messages = [
        {"role": "user", "content": "Explain why LFS uses a temporary toolchain."}
    ]
    inputs = tokenizer.apply_chat_template(
        messages, tokenize=True, add_generation_prompt=True, return_tensors="pt"
    ).to("cuda")
    out = model.generate(input_ids=inputs, max_new_tokens=256, do_sample=True)
    print("=== sample generation ===")
    print(tokenizer.decode(out[0], skip_special_tokens=True))

    if not args.no_gguf:
        model.save_pretrained_merged(args.gguf + "_merged", tokenizer, save_method="merged_16bit")
        model.save_pretrained_gguf(
            args.gguf + "_merged",
            tokenizer,
            quantization_method="q4_k_m",
        )
        print(f"GGUF Q4_K_M exported -> {args.gguf}_merged (for Ollama: ollama create ginger-brain -f Modelfile)")


if __name__ == "__main__":
    main()
