.PRECIOUS: build/%.elf build/%.bin

PORT        ?= /dev/serial/by-id/usb-Arrow_Arrow_USB_Blaster_AR45NPS4-if01-port0
TOOLCHAIN   ?= /opt/riscv/bin/riscv32-unknown-elf-
LOADER      ?= ../software/max1000_riscv_loader/build/max1000_riscv_loader
TARGET      ?= lprs_cpu_bootloader

clean:
	@find build -type f -not -name '.gitignore' -exec rm {} \;

build/%.c.o: ./src/%.c
	@${TOOLCHAIN}gcc \
		-Wall -ffreestanding -g -Os -I include -march=rv32im \
		$^ -c -o $@

build/%.S.o: ./src/%.S
	@${TOOLCHAIN}gcc \
		-Wall -ffreestanding -g -Os -I include -march=rv32im \
		$^ -c -o $@

build/%.elf: ./picorv32.lds \
	$(shell find src -type f \( -name '*.c' -o -name '*.S' \) -printf 'build/%P.o\n')
	@${TOOLCHAIN}gcc \
		-Wall -nostdlib -march=rv32im \
		-Wl,-Bstatic,-T,picorv32.lds,-Map,build/fw_playground.map \
		-Wl,-Bdynamic \
		build/**.o -o $@

build/%.bin: build/%.elf
	@${TOOLCHAIN}objcopy -O binary $^ $@

build/%.lst: build/%.elf
	@${TOOLCHAIN}objdump -S $^ > $@

build/%.hex: build/%.elf
	@${TOOLCHAIN}objcopy -O ihex $^ $@

build/%.fake.hex: build/%.bin
	@utils/makehex.py $^ 3072 $@

build: build/${TARGET}.fake.hex build/${TARGET}.lst

upload: build
	@sudo modprobe ftdi_sio
	@sleep 0.5
	@${LOADER} ${PORT} build/${TARGET}.fake.hex
	@sudo rmmod ftdi_sio || true
	@sudo rmmod usbserial || true
	@jtagconfig
