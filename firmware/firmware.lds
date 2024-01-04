ENTRY(__reset)

MEMORY {
	bram 	(rx) : ORIGIN = 0x00000, LENGTH = 0x10000
	brom 	(r)  : ORIGIN = 0x10000, LENGTH = 0x01000
	sdram	(rw) : ORIGIN = 0x11000, LENGTH = 0xEF000
}

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
	.stack 0x08000 : {
		__stack_end = . ;
		. = . + 0x3FFC;
		__stack_start = . ;
	} > bram
	.mmap 0x0C000 : {
		. = ALIGN(4);
		__mmap_start = . ;
		__gpio_led = . + 0x0000;
		__counter_nanos = . + 0x0004;
		__counter_micros = . + 0x000C;
		__counter_millis = . + 0x0014;
		__timer_reset = . + 0x0020;
		__timer_select = . + 0x0024;
		__timer_interval = . + 0x0028;
		__uart_rx_ready = . + 0x0030;
		__uart_tx_ready = . + 0x0034;
		__uart_rx = . + 0x0038;
		__uart_tx = . + 0x003C;
		__gpio_btn_sw = . + 0x0040;
		__gpio_7segm_hex = . + 0x044;
		__gpio_7segm = . + 0x0048;
		__gpio_disp = . + 0x004c;
		__debug_tx_ready = . + 0x0200;
		__debug_tx = . + 0x0204;
		. = . + 0xFFC;
		__mmap_end = . ;
	} > bram
	__global_pointer = . ;
	.sdram 0x11000 : {
		. = ALIGN(4);
		__sdram_start = . ;
		. = . + 0xEEFFC;
		__sdram_end = . ;
	} > sdram
}
