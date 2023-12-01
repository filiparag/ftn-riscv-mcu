#!/bin/bash

sudo apt-get install autoconf automake autotools-dev curl libmpc-dev \
        libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo \
    gperf libtool patchutils bc zlib1g-dev git libexpat1-dev
	
sudo mkdir /opt/riscv32im
sudo chown $USER /opt/riscv32im

git clone https://github.com/riscv/riscv-gnu-toolchain riscv-gnu-toolchain-rv32im

cd riscv-gnu-toolchain-rv32im

git checkout 411d134

git submodule update --init riscv-gcc
git submodule update --init riscv-binutils
git submodule update --init riscv-newlib
#git submodule update --init riscv-glibc

sudo mkdir /opt/riscv32im

mkdir build; cd build
../configure --with-arch=rv32im --prefix=/opt/riscv32im
make -j$(nproc)

