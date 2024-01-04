#include "../include/memory.h"

void zero_init_bram(void) {
  volatile usize *bram = (usize *)&__sdram_start;
  for (; bram < &__fw_end; ++bram) {
    *bram = 0;
  }
}

void zero_init_sdram(void) {
  volatile usize *sdram = (usize *)&__sdram_start;
  for (; sdram < &__sdram_end; ++sdram) {
    *sdram = 0;
  }
}

void init_ram(void) {
  zero_init_bram();
  zero_init_sdram();
}
