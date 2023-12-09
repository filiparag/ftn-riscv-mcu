#include "picorv_ops.S"

.section .init
.global __reset
.global __irq_handler
.global __irq_mask
.global __irq_wait
.global __init
.type __reset @function
.type __irq_handler @function
.type __irq_mask @function
.type __irq_wait @function
.type __init @function

__reset:

	/* disable all interrupts */

	li		t1, 0xFFFFFFFF
	picorv32_maskirq_insn(x0, t1)

	lui     sp, %hi(__stack_start)
	addi    sp, sp, %lo(__stack_start)

	li		a0, 0xb001
	call	debug

    /* set global pointer */

.option push
.option norelax
    la      gp, __global_pointer
.option pop

	li		a0, 0xb002
	call	debug

    /* clear .bss and .sbss */

	la      a0, __bss_start
	la      a1, __sbss_end
clear_bss:
	bgeu	a0, a1, done_bss
	sw		x0, 0(a0)
	addi	a0, a0, 4
	beq		x0, x0, clear_bss
done_bss:

	li		a0, 0xb003
	call	debug

    j       __init

__irq_handler:

    /* save registers */

    picorv32_setq_insn(q2, x1)
	picorv32_setq_insn(q3, x2)

	lui     x1, %hi(irq_regs)
	addi    x1, x1, %lo(irq_regs)

	picorv32_getq_insn(x2, q0)
	sw      x2,   0*4(x1)

	picorv32_getq_insn(x2, q2)
	sw      x2,   1*4(x1)

	picorv32_getq_insn(x2, q3)
	sw      x2,   2*4(x1)

    sw      x3,   3*4(x1)
	sw      x4,   4*4(x1)
	sw      x5,   5*4(x1)
	sw      x6,   6*4(x1)
	sw      x7,   7*4(x1)
	sw      x8,   8*4(x1)
	sw      x9,   9*4(x1)
	sw      x10, 10*4(x1)
	sw      x11, 11*4(x1)
	sw      x12, 12*4(x1)
	sw      x13, 13*4(x1)
	sw      x14, 14*4(x1)
	sw      x15, 15*4(x1)
	sw      x16, 16*4(x1)
	sw      x17, 17*4(x1)
	sw      x18, 18*4(x1)
	sw      x19, 19*4(x1)
	sw      x20, 20*4(x1)
	sw      x21, 21*4(x1)
	sw      x22, 22*4(x1)
	sw      x23, 23*4(x1)
	sw      x24, 24*4(x1)
	sw      x25, 25*4(x1)
	sw      x26, 26*4(x1)
	sw      x27, 27*4(x1)
	sw      x28, 28*4(x1)
	sw      x29, 29*4(x1)
	sw      x30, 30*4(x1)
	sw      x31, 31*4(x1)

    /* call interrupt handler C function */

	lui     sp, %hi(irq_stack_start)
	addi    sp, sp, %lo(irq_stack_start)

    picorv32_getq_insn(a0, q1) // arg1 = interrupt type

	call	__irq // call to C function

    /* restore registers */

	lui     x1, %hi(irq_regs)
	addi    x1, x1, %lo(irq_regs)

	lw      x2,   0*4(x1)
	picorv32_setq_insn(q0, x2)

	lw      x2,   1*4(x1)
	picorv32_setq_insn(q1, x2)

	lw      x2,   2*4(x1)
	picorv32_setq_insn(q2, x2)

    lw      x3,   3*4(x1)
	lw      x4,   4*4(x1)
	lw      x5,   5*4(x1)
	lw      x6,   6*4(x1)
	lw      x7,   7*4(x1)
	lw      x8,   8*4(x1)
	lw      x9,   9*4(x1)
	lw      x10, 10*4(x1)
	lw      x11, 11*4(x1)
	lw      x12, 12*4(x1)
	lw      x13, 13*4(x1)
	lw      x14, 14*4(x1)
	lw      x15, 15*4(x1)
	lw      x16, 16*4(x1)
	lw      x17, 17*4(x1)
	lw      x18, 18*4(x1)
	lw      x19, 19*4(x1)
	lw      x20, 20*4(x1)
	lw      x21, 21*4(x1)
	lw      x22, 22*4(x1)
	lw      x23, 23*4(x1)
	lw      x24, 24*4(x1)
	lw      x25, 25*4(x1)
	lw      x26, 26*4(x1)
	lw      x27, 27*4(x1)
	lw      x28, 28*4(x1)
	lw      x29, 29*4(x1)
	lw      x30, 30*4(x1)
	lw      x31, 31*4(x1)

    picorv32_getq_insn(x1, q1)
	picorv32_getq_insn(x2, q2)

    picorv32_retirq_insn()

irq_regs:
    .fill   32, 4
irq_stack_end:
    .fill   256, 4
irq_stack_start:

debug:

	li      a5, 0x8000
	sw      a0, 4(a5)
	ret

__irq_mask:

	picorv32_maskirq_insn(a0, a0)
	ret

__irq_wait:

	picorv32_waitirq_insn(a0)
	ret

__init:

	li		a0, 0xb004
	call	debug

	/* zero-initialize all registers */

	addi 	x1, zero, 0
	addi 	x2, zero, 0
	addi 	x3, zero, 0
	addi 	x4, zero, 0
	addi 	x5, zero, 0
	addi 	x6, zero, 0
	addi 	x7, zero, 0
	addi 	x8, zero, 0
	addi 	x9, zero, 0
	addi 	x10, zero, 0
	addi 	x11, zero, 0
	addi 	x12, zero, 0
	addi 	x13, zero, 0
	addi 	x14, zero, 0
	addi 	x15, zero, 0
	addi 	x16, zero, 0
	addi 	x17, zero, 0
	addi 	x18, zero, 0
	addi 	x19, zero, 0
	addi 	x20, zero, 0
	addi 	x21, zero, 0
	addi 	x22, zero, 0
	addi 	x23, zero, 0
	addi 	x24, zero, 0
	addi 	x25, zero, 0
	addi 	x26, zero, 0
	addi 	x27, zero, 0
	addi 	x28, zero, 0
	addi 	x29, zero, 0
	addi 	x30, zero, 0
	addi 	x31, zero, 0

    lui     sp, %hi(__stack_start)
	addi    sp, sp, %lo(__stack_start)

	call	__irq_init
    j       main

    ebreak
