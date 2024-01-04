#include "../include/picorv32.h"

.section .init

.global __reset
.global __irq_handler
.global __init
.global __exit

.type __reset @function
.type __irq_handler @function
.type __init @function
.type __exit @function

__reset:

	/* disable all interrupts */

	li		t1, 0xFFFFFFFF
	picorv32_maskirq_insn(x0, t1)

	lui     sp, %hi(__stack_start)
	addi    sp, sp, %lo(__stack_start)

    /* set global pointer */

.option push
.option norelax
    la      gp, __global_pointer
.option pop

    j       __init

__irq_handler:

	j		__fw_irq_handler

__init:

    lui     sp, %hi(__stack_start)
	addi    sp, sp, %lo(__stack_start)

    j       main

    ebreak

__exit:

	j		__fw_reset
