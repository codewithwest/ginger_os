#!/usr/bin/env bash
# Helper script to remount the LFS image and run host finalization again.
# Usage: ./remount_and_finalize.sh

set -e

# Load environment variables (LFS, etc.)
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../config" && pwd)/env.sh"

# Ensure LFS is defined
if [ -z "${LFS:-}" ]; then
  echo "ERROR: LFS variable is not set. Ensure config/env.sh defines it."
  exit 1
fi

# Remount the LFS image (creates if missing)
# This script will create the image if it does not exist and mount it to $LFS
"$(cd "$(dirname "${BASH_SOURCE[0]}")/../image" && pwd)/prepare-image.sh"

# Run the host finalization script
# "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/finalize-system.sh"
