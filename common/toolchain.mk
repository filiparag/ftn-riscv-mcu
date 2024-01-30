COMMON_DIR	:= $(shell realpath -s $(dir $(lastword $(MAKEFILE_LIST))))

E2X_TOOLCHAIN	?= ${COMMON_DIR}/tools/elf2hex
RV32_TOOLCHAIN	?= ${COMMON_DIR}/tools/gnu_toolchain
RV32_TARGET	?= riscv32-unknown-elf
RV32_ARCH	?= rv32im
RV32_ABI	?= ilp32
