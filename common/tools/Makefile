.PHONY: all

include ../toolchain.mk

PATH		:= ${RV32_TOOLCHAIN}/bin:${E2X_TOOLCHAIN}/bin:${PATH}
MAKEFLAGS	+= --silent

GNU_GCC_BRANCH	?= 2023.12.20
ELF2HEX_BRANCH	?= v20.08.00.00


all: download build
download: download-gnu download-e2x
build: build-gnu build-e2x

download-gnu:
	git clone --depth 1 --branch ${GNU_GCC_BRANCH} \
		https://github.com/riscv-collab/riscv-gnu-toolchain \
		${CURDIR}/riscv-gnu-toolchain

download-e2x:
	git clone --depth 1 --branch ${ELF2HEX_BRANCH} \
		https://github.com/sifive/elf2hex \
		${CURDIR}/sifive_elf2hex

build-gnu:
	mkdir -p ${CURDIR}/riscv-gnu-toolchain/build
	cd ${CURDIR}/riscv-gnu-toolchain/build && \
		../configure \
			--with-arch=${RV32_ARCH} \
			--with-abi=${RV_ABI} \
			--prefix=${CURDIR}/gnu_toolchain
	cd ${CURDIR}/riscv-gnu-toolchain/build && \
		make -j$(nproc)

build-e2x:
	cd ${CURDIR}/sifive_elf2hex && \
		autoreconf -i
	cd ${CURDIR}/sifive_elf2hex && \
		./configure \
			--target=${RV32_TARGET} \
			--prefix=${CURDIR}/elf2hex
	cd ${CURDIR}/sifive_elf2hex && \
		make && \
		make install

clean-sources:
	rm -rf ${CURDIR}/riscv-gnu-toolchain \
		${CURDIR}/sifive_elf2hex

clean:
	rm -rf ${CURDIR}/gnu_toolchain \
		${CURDIR}/elf2hex
