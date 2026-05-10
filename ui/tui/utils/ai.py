# ui/tui/utils/ai.py

def get_ai_thought(step_name: str):

    step = step_name.lower()

    if "host" in step:
        return (
            "Verifying ecosystem dependencies."
        )

    if "toolchain" in step:
        return (
            "Synthesizing binary primitives."
        )

    if "kernel" in step:
        return (
            "Calibrating scheduler and memory."
        )

    return (
        f"Executing directive: {step_name}"
    )
