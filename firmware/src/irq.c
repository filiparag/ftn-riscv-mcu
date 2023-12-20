#include "../include/irq.h"
#include "../include/gpio.h"
#include "../include/types.h"

static irq_fn irq_vector[IRQ_COUNT];

usize irq_enable(const enum IRQ mask) { return ~__irq_mask(~mask); }

void irq_wait(const enum IRQ mask) { __irq_wait(mask); }

void irq_set_handler(const enum IRQ irq, const irq_fn handler) {
  usize bitmap = irq;
  usize index = 0;
  while (!(bitmap & 1)) {
    bitmap >>= 1;
    ++index;
  }
  irq_vector[index] = handler;
}

void __irq_init(void) {
  __gpio_7segm_hex = 0xb005;
  for (usize i = 0; i < IRQ_COUNT; ++i) {
    irq_vector[i] = IRQ_UNSET;
  }
}

void __isr(const usize irqs) {
  volatile usize j = 0;
  for (usize i = 0; i < IRQ_COUNT; ++i) {
    if (((1 << i) & irqs) && (irq_vector[i] != IRQ_UNSET)) {
      ++j;
      irq_vector[i](irqs);
    }
  }
}
