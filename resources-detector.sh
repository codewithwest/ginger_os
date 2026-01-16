#!/bin/bash
# auto-vm-resources.sh
# Calculate optimal RAM and CPU for QEMU VM based on host usage

# -----------------------------
# CPU calculation
# -----------------------------
TOTAL_CPUS=$(nproc)                       # total logical CPUs
LOAD_AVG=$(awk '{print $1}' /proc/loadavg) # current load average (1 min)
RESERVE_CPUS=2                             # always leave 2 CPUs for host

# Calculate recommended CPUs for VM
VM_CPUS=$((TOTAL_CPUS - RESERVE_CPUS))
if [ "$VM_CPUS" -lt 1 ]; then
    VM_CPUS=1
fi

# -----------------------------
# RAM calculation
# -----------------------------
# Get available memory in MiB
AVAILABLE_MEM=$(free -m | awk '/Mem:/ {print $7}')
RESERVE_RAM=8192  # leave 8 GiB for host
VM_RAM=$((AVAILABLE_MEM - RESERVE_RAM))
if [ "$VM_RAM" -lt 512 ]; then
    VM_RAM=512   # minimum 512 MiB
fi

# Round down to nearest 512 MiB for safety
VM_RAM=$((VM_RAM / 512 * 512))

# -----------------------------
# Output recommended QEMU command
# -----------------------------
echo "Host has $TOTAL_CPUS CPUs, $AVAILABLE_MEM MiB available RAM"
echo "Recommended VM allocation: $VM_CPUS CPUs, ${VM_RAM} MiB RAM"
echo ""
echo "Example QEMU command:"
echo "qemu-system-x86_64 -enable-kvm -m ${VM_RAM}M -smp ${VM_CPUS} \\"
echo "  -drive file=ginger_os.img,format=raw -serial stdio"
