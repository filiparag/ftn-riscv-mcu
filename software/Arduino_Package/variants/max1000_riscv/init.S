.section .init
.global main

/* set stack pointer */
/* stack should start at 0x4eeb40 */
/* Keep it synced with firmware.lds */
/* lui sp, %hi(0x400) */
lui sp, %hi(0x500000) 
/* addi sp, sp, %lo(0x400) */
/* addi sp, sp, %lo(0x800) */  /* give max stack address */

/* call main */
jal ra, main

/* break */
ebreak
