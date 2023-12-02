.section .init
.global __reset
    lui sp, %hi(0x7FFC)
    jal ra, main
    ebreak

.global __irq0
    jal ra, main

.global __irq1
    jal ra, main

.global __irq2
    jal ra, main
