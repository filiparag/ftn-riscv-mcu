.PHONY: all

include ../../common/toolchain.mk

CFLAGS		+= -DPREFER_SIZE_OVER_SPEED=1 -Os
MAKEFLAGS 	+= --silent
PATH		:= ${RV32_TOOLCHAIN}:${PATH}

NEWLIB_VERSION	= 4.4.0.20231231

all: download build

download:
	curl -O 'ftp://sourceware.org/pub/newlib/newlib-${NEWLIB_VERSION}.tar.gz'
	tar xf newlib-${NEWLIB_VERSION}.tar.gz
	rm newlib-${NEWLIB_VERSION}.tar.gz

build:
	mkdir -p ${CURDIR}/newlib
	cd ${CURDIR}/newlib && \
		${CURDIR}/newlib-4.4.0.20231231/configure \
			--target=riscv32-unknown-elf \
			--enable-newlib-io-pos-args \
			--enable-newlib-io-c99-formats \
			--enable-newlib-nano-malloc \
			--enable-target-optspace \
			--enable-lite-exit \
			--enable-newlib-nano-formatted-io \
			--disable-newlib-fvwrite-in-streamio \
			--disable-newlib-atexit-dynamic-alloc \
			--disable-newlib-fseek-optimization \
			--disable-newlib-wide-orient \
			--disable-newlib-unbuf-stream-opt \
			--disable-newlib-supplied-syscalls
	cd ${CURDIR}/newlib && \
		make -j$(nproc)

clean:
	rm -rf ${CURDIR}/newlib
