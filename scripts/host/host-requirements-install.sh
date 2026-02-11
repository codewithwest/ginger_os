sudo apt update
sudo apt install -y \
    build-essential bison gawk m4 texinfo \
    libncurses5-dev libtool autoconf automake \
    patch wget curl xz-utils bzip2 \
    file bc flex zlib1g-dev \
    xorriso 

# Create lfs user and group if missing
if ! id lfs >/dev/null 2>&1; then
    sudo groupadd lfs
    sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
    echo "lfs:lfs" | sudo chpasswd
fi
