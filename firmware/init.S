.section .init
.global __reset
    lui sp, %hi(0xAFFC)
    jal ra, main
    ebreak
