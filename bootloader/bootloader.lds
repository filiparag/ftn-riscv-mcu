ENTRY(__reset)

MEMORY {
	bram 	(rw) : ORIGIN = 0x00000, LENGTH = 0x10000
	brom 	(rx) : ORIGIN = 0x10000, LENGTH = 0x01000
	sdram	(rw) : ORIGIN = 0x11000, LENGTH = 0xEF000
}

INCLUDE ../common/sections.ld

SECTIONS {
	.firmware 0x00000 : {
		. = ALIGN(4);
		__fw_start = . ;
		__fw_reset = . + 0x0;
		__fw_irq_handler = . + 0x60;
		. = . + 0x07FFC;
		__fw_end = . ;
	} > bram
	.text 0x10000 : {
		. = ALIGN(4);
		*(.init)
		__reset = 0x0;
		__irq_handler = 0x60;
		__text_start = . ;
		*(.text)
		*(.data)
		*(.strings)
		__text_end = . ;
	} > brom
}
