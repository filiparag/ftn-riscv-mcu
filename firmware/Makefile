.PRECIOUS: build/%.elf

PORT        ?= /dev/ttyUSB0
TOOLCHAIN   ?= ~/.arduino15/packages/max1000/tools/riscv32-unknown-elf-gcc/8.2.0-im/bin/riscv32-unknown-elf-
LOADER      ?= ../software/max1000_riscv_loader/build/max1000_riscv_loader
TARGET      ?= lprs_cpu_bootloader

clean:
	find build -type f -not -name '.gitignore' -exec rm {} \;

build/%.c.o: ./src/%.c
	${TOOLCHAIN}gcc -Wall -ffreestanding -g -Os -I include $^ -c -o $@

build/%.S.o: ./src/%.S
	${TOOLCHAIN}gcc -Wall -ffreestanding -g -Os -I include $^ -c -o $@

build/%.elf: $(shell find src -type f \( -name '*.c' -o -name '*.S' \) -printf 'build/%P.o\n')
	${TOOLCHAIN}gcc -Wall -nostdlib build/**.o -o $@ -Wl,-Bstatic,-T,picorv32.lds,-Map,build/fw_playground.map -Wl,-Bdynamic

build/%.bin: build/%.elf
	${TOOLCHAIN}objcopy -O binary $^ $@

build/%.lst: build/%.elf
	${TOOLCHAIN}objdump -S $^ > $@

build/%.hex: build/%.elf
	${TOOLCHAIN}objcopy -O ihex $^ $@

build/%.fake.hex: build/%.bin
	utils/makehex.py $^ 3072 $@

build: build/${TARGET}.fake.hex

upload: build/${TARGET}.fake.hex
	sudo modprobe ftdi_sio
	${LOADER} ${PORT} build/${TARGET}.fake.hex
	sudo rmmod ftdi_sio
	sudo rmmod usbserial || true
	jtagconfig
