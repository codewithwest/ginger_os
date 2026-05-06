import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lfs_builder_ui import GingerEngine

engine = GingerEngine(dry_run=True)
print("GINGER_OS_STEPS:")
for idx, step in enumerate(engine.steps, 1):
    print(f"{idx:02d} | {step.id:20s} | {step.name}")
