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
	.stack 0x3000 : {
		__stack_end = . ;
		. = . + 0x4FFC;
		__stack_start = . ;
	} > bram
	.mmap 0x8000 : {
		. = ALIGN(4);
		__mmap_start = . ;
		__gpio_led = . + 0x0000;
		__counter_nanos = . + 0x0004;
		__counter_micros = . + 0x000C;
		__counter_millis = . + 0x0014;
		__timer_reset = . + 0x0020;
		__timer_select = . + 0x0024;
		__timer_interval = . + 0x0028;
		__uart_rx_recv = . + 0x0040;
		__uart_rx = . + 0x0044;
		__uart_tx = . + 0x0048;
		__gpio_7segm_hex = . + 0x060;
		__gpio_7segm = . + 0x0064;
		__gpio_btn_sw = . + 0x0068;
		. = . + 0xFFC;
		__mmap_end = . ;
	} > bram
}
