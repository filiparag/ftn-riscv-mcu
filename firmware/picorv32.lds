BRAM_SIZE = 0xC000;
SDRAM_SIZE = 0x100000;

ENTRY(__reset)

MEMORY {
	bram (rwx) : ORIGIN = 0x0, LENGTH = BRAM_SIZE
	sdram (rwx) : ORIGIN = 0xC000, LENGTH = SDRAM_SIZE
}

SECTIONS {
	.text 0x0 : {
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
	__global_pointer = . ;
	.bss : {
		__bss_start = . ;
		*(.bss)
		*(.common)
		__bss_end = . ;
	} > bram
	.sbss : AT (__bss_end) {
		__sbss_start = . ;
		*(.sbss)
		__sbss_end = . ;
	} > bram
	.stack 0x1000 : {
		__stack_end = . ;
		. = . + 0x6FFC;
		__stack_start = . ;
	} > bram
	.lprs1 0x8000 : {
		. = ALIGN(4);
		__lprs1_start = . ;
		__gpio_led = . ;
		__gpio_7segm_hex = . + 0x004;
		__gpio_7segm = . + 0x008;
		__gpio_btn_sw = . + 0x00C;
		__uart_rx_ready = . + 0xFF4;
		__uart_rx = . + 0xFF8;
		__uart_tx = . + 0xFFC;
		. = . + 0xFFC;
		__lprs1_end = . ;
	} > bram
}
