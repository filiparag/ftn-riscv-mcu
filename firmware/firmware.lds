ENTRY(__reset)

MEMORY {
	bram 	(rx) : ORIGIN = 0x00000, LENGTH = 0x10000
	brom 	(r)  : ORIGIN = 0x10000, LENGTH = 0x01000
	sdram	(rw) : ORIGIN = 0x11000, LENGTH = 0xEF000
}

INCLUDE ../common/sections.ld

SECTIONS {
	.text 0x00000 : {
		. = ALIGN(4);
		*(.init)
		__reset = 0x0;
		__irq_handler = 0x60;
		__text_start = . ;
		*(.text)
		*(.data)
		*(.strings)
		__text_end = . ;
	} > bram
}
