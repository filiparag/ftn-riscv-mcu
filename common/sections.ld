SECTIONS {
	.bss 0x08000 : {
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
	.stack 0x08800 : {
		__stack_end = . ;
		. = . + 0x37FC;
		__stack_start = . ;
	} > bram
	.mmap 0x0C000 : {
		. = ALIGN(4);
		__mmap_start = . ;
		__gpio_led_sem = . + 0x0000;
		__counter_nanos = . + 0x0004;
		__counter_micros = . + 0x000C;
		__counter_millis = . + 0x0014;
		__timer_reset = . + 0x0020;
		__timer_select = . + 0x0024;
		__timer_interval = . + 0x0028;
		__uart0_rx_ready = . + 0x0030;
		__uart0_tx_ready = . + 0x0034;
		__uart1_rx_ready = . + 0x0038;
		__uart1_tx_ready = . + 0x003C;
		__uart0_rx = . + 0x0040;
		__uart0_tx = . + 0x0044;
		__uart1_rx = . + 0x0048;
		__uart1_tx = . + 0x004C;
		__gpio_btn_sw = . + 0x0050;
		__gpio_7segm_hex = . + 0x054;
		__gpio_7segm = . + 0x0058;
		__gpio_disp = . + 0x005c;
		__debug_tx_ready = . + 0x0200;
		__debug_tx = . + 0x0204;
		. = . + 0xFFC;
		__mmap_end = . ;
	} > bram
	.sdram 0x11000 : {
		. = ALIGN(4);
        __global_pointer = . ;
		__sdram_start = . ;
		. = . + 0xEEFFC;
		__sdram_end = . ;
	} > sdram
}
