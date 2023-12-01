/* Constants */

/* BRAM_SIZE = 0x2000; */ 
BRAM_SIZE = 0x3000; 
/* BRAM_SIZE = 0x2FFC; */ 
SDRAM_SIZE = 0x100000; 
/* SDRAM_SIZE_TEST = 0x1000000; */


/* Keep it synced with firmware.S */
STACK_SIZE = 0x800;
STACK_ORIGIN = 0x00500000;

/* Memory layout - name (attributes) : ORIGIN = start address, LENGTH = size */

MEMORY {
	bram (rwx) : ORIGIN = 0x00000000, LENGTH = BRAM_SIZE
	sdram (rwx) : ORIGIN = 0x00400000, LENGTH = SDRAM_SIZE
}

SECTIONS {
	.text : {
		__text_start = 0x00000000;
		*(.init)		
		*(.text)
		*(.data)
		*(.strings)
		. = ALIGN(4);
		__text_end = . ;
	} > bram
	.bss : {
		__bss_start = 0x00400000;
		*(.bss)
		*(.common)
		__bss_end = . ;
	} > sdram
	.sbss : AT (__bss_end) {
		__sbss_start = . ;
		*(.sbss)
		__sbss_end = . ;
	} > sdram
/* 	.stack : AT (__sbss_end) {
		__stack_start = . ;
		. = . + STACK_SIZE;
		__stack_end = . ;
	} > sdram */
	.stack : {
		__stack_start = 0x00500000;
		__stack_end = 0x004FF800;
	} > sdram 
}
