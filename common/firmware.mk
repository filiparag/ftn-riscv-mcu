.PRECIOUS: build/%.elf

COMMON_DIR	:= $(dir $(lastword $(MAKEFILE_LIST)))
include ${COMMON_DIR}/toolchain.mk

MAKEFLAGS 	+= --silent
TOOLCHAIN	:= ${RV32_TOOLCHAIN}/bin/${RV32_TARGET}-

clean:
	find ${CURDIR}/build -type f -not -name '.gitignore' -exec rm {} \;

build/%.c.o: ./src/%.c
	${TOOLCHAIN}gcc \
		-std=c2x -Wall -ffreestanding -g -Os -I include -march=${RV32_ARCH} \
		$^ -c -o $@

build/%.cpp.o: ./src/%.cpp
	${TOOLCHAIN}gcc \
		-std=c++2b -Wall -ffreestanding -g -Os -I include -march=${RV32_ARCH} \
		$^ -c -o $@

build/%.S.o: ./src/%.S
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
		-Wl,-Bdynamic ${CURDIR}/build/**.o ${CURDIR}/build/**.a -lm -lc -lgcc \
		-o $@
else
	${TOOLCHAIN}gcc \
		-Os -Wall -nostdlib -march=${RV32_ARCH} \
		-Wl,-Bstatic,-T,${LINKER_SCRIPT},-Map,${CURDIR}/build/fw_playground.map \
		-Wl,-Bdynamic ${CURDIR}/build/**.o \
		-o $@
endif

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

