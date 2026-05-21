"""
Build steps definitions and management for GingerOS.
"""

from server.models import BuildStep
from config.constants import LFS_MOUNT


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
            "01. Create QEMU Image",
            "bash ./lfs/image/01-prepare-image.sh",
            "Preparation",
        ),
        BuildStep(
            "02_install_ubuntu",
            "02. Install Ubuntu Base",
            "sudo bash ./lfs/image/02-install-ubuntu.sh",
            "Preparation",
        ),
        # Host Setup
        BuildStep(
            "03_host_requirements",
            "03. Host Requirements",
            "sudo bash ./lfs/host/03-host-requirements.sh",
            "Host Setup",
        ),
        BuildStep(
            "04_setup_downloads",
            "04. Download Sources",
            "bash ./lfs/host/04-download.sh",
            "Host Setup",
        ),
        BuildStep(
            "05_host_setup",
            "05. Host Environment",
            "sudo bash ./lfs/host/05-setup-host.sh",
            "Host Setup",
        ),
        BuildStep(
            "06_version_check",
            "06. Version Check",
            "bash ./lfs/host/06-version-check.sh",
            "Host Setup",
        ),
        # Phase 1 Tools
        BuildStep(
            "07_phase1_tools",
            "07. Phase 1 Tools",
            f"sudo bash ./lfs/host/run-as-lfs.sh {LFS_MOUNT}/lfs/phases/07-build-phase1.sh",
            "Phase 1 Tools",
        ),
        # Phase 2 Tools
        BuildStep(
            "08_phase2_tools",
            "08. Phase 2 Tools",
            f"sudo bash ./lfs/host/run-as-lfs.sh {LFS_MOUNT}/lfs/phases/08-build-phase2.sh",
            "Phase 2 Tools",
        ),
        # Phase 3 System
        BuildStep(
            "09_chroot_mounts",
            "09. Mount Chroot",
            "sudo bash ./lfs/phases/09-chroot-mounts.sh",
            "Phase 3 System",
        ),
        BuildStep(
            "10_phase3_system",
            "10. System Build",
            "sudo bash lfs/chroot.sh /lfs/phases/10-build-phase3.sh",
            "Phase 3 System",
        ),
        # Kernel & Boot
        BuildStep(
            "11_kernel",
            "11. Kernel Build",
            "sudo bash lfs/chroot.sh /lfs/phases/11-build-phase4.sh",
            "Kernel & Boot",
        ),
        BuildStep(
            "12_finalize",
            "12. Finalize System",
            "sudo bash ./lfs/host/12-finalize-system.sh",
            "Kernel & Boot",
        ),
        BuildStep(
            "13_teardown",
            "13. Teardown",
            "bash ./lfs/image/13-teardown.sh",
            "Kernel & Boot",
        ),
    ]
