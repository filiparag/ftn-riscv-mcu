.PHONY: all

LINKER_SCRIPT	?= firmware.lds
INCLUDE_LIBS	?= true
TARGET		?= firmware

AVRDUDE_UART	?= /dev/serial/by-id/usb-Arrow_Arrow_USB_Blaster_AR45NPS4-if01-port0
AVRDUDE_PARTNO	?= atmega328p
AVRDUDE_PROG	?= arduino
BAUD_RATE	?= 115200

all: build/${TARGET}.intel.hex build/${TARGET}.quartus.hex build/${TARGET}.lst

upload: build/${TARGET}.intel.hex
	avrdude \
		-v -D \
		-U flash:w:build/${TARGET}.intel.hex:i \
		-p ${AVRDUDE_PARTNO} \
		-c ${AVRDUDE_PROG} \
		-b ${BAUD_RATE} \
		-P ${AVRDUDE_UART}

include ../common/firmware.mk
