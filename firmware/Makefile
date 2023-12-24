.PRECIOUS: build/%.elf build/%.bin

RV32_TOOLCHAIN	?= /opt/riscv/bin/riscv32-unknown-elf-
RV32_ARCH	?= rv32im
LINKER_SCRIPT	?= picorv32.lds
UART_DMA	?= /dev/serial/by-id/usb-Arrow_Arrow_USB_Blaster_AR45NPS4-if01-port0
UART_AVRDUDE	?= /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_A50285BI-if00-port0
DMA_LOADER	?= ../software/max1000_riscv_loader/build/max1000_riscv_loader
TARGET		?= lprs_cpu_bootloader
AVRDUDE_PARTNO	?= atmega328p
AVRDUDE_PROG	?= arduino
BAUD_RATE	?= 115200

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

build/%.hex: build/%.elf
	@${RV32_TOOLCHAIN}objcopy -O ihex $^ $@

build/%.fake.hex: build/%.bin
	@utils/makehex.py $^ 3072 $@

build: build/${TARGET}.fake.hex build/${TARGET}.lst

upload: build
	@sudo modprobe ftdi_sio
	@sleep 0.5
	@${DMA_LOADER} ${UART_DMA} build/${TARGET}.fake.hex
	@sudo rmmod ftdi_sio || true
	@sudo rmmod usbserial || true
	@jtagconfig

intercept:
	@sudo interceptty -l -v \
		${UART_AVRDUDE} \
		/dev/ttyINTRCPT | awk -f ./utils/interceptty.awk

avrdude: build/${TARGET}.hex
	@avrdude \
		-v -p ${AVRDUDE_PARTNO} -c ${AVRDUDE_PROG} \
		-b ${BAUD_RATE} -D \
		-U flash:w:build/${TARGET}.hex \
		-P /dev/ttyINTRCPT
