.PRECIOUS: build/%.elf build/%.bin
.PHONY: build

RV32_TOOLCHAIN	?= /opt/riscv/bin/riscv32-unknown-elf-
RV32_ARCH	?= rv32im
E2X_TOOLCHAIN	?= /opt/elf2hex/
LINKER_SCRIPT	?= bootloader.lds
TARGET		?= bootloader

clean:
	@find build -type f -not -name '.gitignore' -exec rm {} \;

build/%.c.o: ./src/%.c
	@${RV32_TOOLCHAIN}gcc \
		-Wall -ffreestanding -g -Os -I include -march=${RV32_ARCH} \
		$^ -c -o $@

build/%.S.o: ./src/%.S
	@${RV32_TOOLCHAIN}gcc \
		-Wall -ffreestanding -g -Os -I include -march=${RV32_ARCH} \
		$^ -c -o $@

build/%.elf: ./${LINKER_SCRIPT} \
	$(shell find src -type f \( -name '*.c' -o -name '*.S' \) -printf 'build/%P.o\n')
	@${RV32_TOOLCHAIN}gcc \
		-Wall -nostdlib -march=${RV32_ARCH} \
		-Wl,-Bstatic,-T,${LINKER_SCRIPT},-Map,build/fw_playground.map \
		-Wl,-Bdynamic \
		build/**.o -o $@

build/%.bin: build/%.elf
	@${RV32_TOOLCHAIN}objcopy -O binary $^ $@

build/%.lst: build/%.elf
	@${RV32_TOOLCHAIN}objdump -S $^ > $@

build/%.intel.hex: build/%.elf
	@${RV32_TOOLCHAIN}objcopy -O ihex $^ $@

build/%.quartus.hex: build/%.elf
	@${E2X_TOOLCHAIN}elf2hex \
		--bit-width 32 \
		--input $^ \
		--output /dev/stdout | \
	awk -f ../common/scripts/quartus_ihex.awk > $@

build: build/${TARGET}.quartus.hex build/${TARGET}.lst
