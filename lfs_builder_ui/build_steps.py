"""
Build steps definitions and management for GingerOS.
"""

import os
from .models import BuildStep
from .constants import LFS_MOUNT


def get_build_steps():
    """
    Define all build steps for the GingerOS LFS build process.

    Returns:
        list: List of BuildStep objects defining the complete build pipeline.
    """
    return [
        # Preparation Phase
        BuildStep(
            "01_create_qemu_img",
            "Create QEMU Image",
            "bash ./scripts/image/prepare-image.sh",
            "Preparation",
        ),
        BuildStep(
            "02_install_ubuntu",
            "Install Ubuntu Base",
            "sudo bash ./scripts/image/install-ubuntu.sh",
            "Preparation",
        ),
        # Host Setup
        BuildStep(
            "03_host_requirements",
            "Host Requirements",
            "sudo bash ./scripts/host/host-requirements-install.sh",
            "Host Setup",
        ),
        BuildStep(
            "04_setup_downloads",
            "Download Sources",
            "bash ./scripts/host/download.sh",
            "Host Setup",
        ),
        BuildStep(
            "05_host_setup",
            "Host Environment",
            "sudo bash ./scripts/host/setup-host.sh",
            "Host Setup",
        ),
        BuildStep(
            "06_version_check",
            "Version Check",
            "bash ./scripts/host/version-check.sh",
            "Host Setup",
        ),
        # Phase 1 Tools
        BuildStep(
            "07_phase1_tools",
            "Phase 1 Tools",
            f"sudo bash ./scripts/host/run-as-lfs.sh {LFS_MOUNT}/scripts/phases/build-phase1.sh",
            "Phase 1 Tools",
        ),
        # Phase 2 Tools
        BuildStep(
            "08_phase2_tools",
            "Phase 2 Tools",
            f"sudo bash ./scripts/host/run-as-lfs.sh {LFS_MOUNT}/scripts/phases/build-phase2.sh",
            "Phase 2 Tools",
        ),
        # Phase 3 System
        BuildStep(
            "09_chroot_mounts",
            "Mount Chroot",
            "sudo bash scripts/chroot.sh --mount-only",
            "Phase 3 System",
        ),
        BuildStep(
            "10_phase3_system",
            "System Build",
            "sudo bash scripts/chroot.sh /scripts/phases/build-phase3.sh",
            "Phase 3 System",
        ),
        # Kernel & Boot
        BuildStep(
            "11_kernel",
            "Kernel Build",
            "sudo bash scripts/chroot.sh /scripts/phases/build-phase4.sh",
            "Kernel & Boot",
        ),
        BuildStep(
            "12_finalize",
            "Finalize System",
            "sudo bash scripts/host/finalize-system.sh",
            "Kernel & Boot",
        ),
        BuildStep(
            "13_teardown",
            "Teardown",
            "bash scripts/image/teardown.sh",
            "Kernel & Boot",
        ),
    ]
