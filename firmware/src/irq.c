#include "../include/gpio.h"

uint32_t *irq(uint32_t *regs, uint32_t irqs) {
  __gpio_7segm_hex = irqs;
  return regs;
}
