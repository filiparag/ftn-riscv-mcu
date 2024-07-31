.PRECIOUS: build/%.elf

COMMON_DIR	:= $(dir $(lastword $(MAKEFILE_LIST)))
include ${COMMON_DIR}/toolchain.mk

MAKEFLAGS 	+= --silent
TOOLCHAIN	:= ${RV32_TOOLCHAIN}/bin/${RV32_TARGET}-

clean:
	find ${CURDIR}/build -mindepth 1 -maxdepth 1 -not -name '.gitignore' -exec rm -rf {} \;

build/%.c.o: ./src/%.c
	mkdir -p "$$(dirname $@)"
	${TOOLCHAIN}gcc \
		-std=c2x -Wall -ffreestanding -g -Os -I include -march=${RV32_ARCH} \
		$^ -c -o $@

build/%.cpp.o: ./src/%.cpp
	mkdir -p "$$(dirname $@)"
	${TOOLCHAIN}gcc \
		-std=c++2b -Wall -ffreestanding -g -Os -I include -march=${RV32_ARCH} \
		$^ -c -o $@

build/%.S.o: ./src/%.S
	mkdir -p "$$(dirname $@)"
	${TOOLCHAIN}gcc \
		-Wall -ffreestanding -g -Os -I include -march=${RV32_ARCH} \
		$^ -c -o $@

build/%.elf: ./${LINKER_SCRIPT} \
	$(shell find ${CURDIR}/src -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.S' \) -printf 'build/%P.o\n')
ifdef INCLUDE_LIBS
	find ${CURDIR}/lib/newlib/${RV32_TARGET}/newlib \
	  	-type f -name '*.a' \
	 	-exec cp -f {} ${CURDIR}/build \;
	${TOOLCHAIN}gcc \
		-Os -Wall -nostdlib -march=${RV32_ARCH} \
		-Wl,-Bstatic,-T,${LINKER_SCRIPT},-Map,${CURDIR}/build/fw_playground.map \
		-Wl,-Bdynamic $(shell echo $^ | cut -d ' ' -f 2-) ${CURDIR}/build/**.a -lm -lc -lgcc \
		-o $@
else
	${TOOLCHAIN}gcc \
		-Os -Wall -nostdlib -march=${RV32_ARCH} \
		-Wl,-Bstatic,-T,${LINKER_SCRIPT},-Map,${CURDIR}/build/fw_playground.map \
		-Wl,-Bdynamic $(shell echo $^ | cut -d ' ' -f 2-) \
		-o $@
endif
	${TOOLCHAIN}strip $@

build/%.bin: build/%.elf
	${TOOLCHAIN}objcopy -O binary $^ $@

build/%.lst: build/%.elf
	${TOOLCHAIN}objdump -S $^ > $@

build/%.intel.hex: build/%.elf
	${TOOLCHAIN}objcopy -O ihex $^ $@

build/%.plain.hex: build/%.elf
	${E2X_TOOLCHAIN}/bin/${RV32_TARGET}-elf2hex \
		--bit-width 32 \
		--input $^ \
		--output $@

build/%.quartus.hex: build/%.plain.hex
	awk -f ${COMMON_DIR}/scripts/quartus_ihex.awk $^ > $@

