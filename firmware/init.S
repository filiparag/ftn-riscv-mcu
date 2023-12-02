.section .init
.global __reset
    lui sp, %hi(0x7FFC)
    jal ra, main
    ebreak
