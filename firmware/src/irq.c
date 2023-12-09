#include "../include/types.h"

#include "../include/gpio.h"
#include "../include/irq.h"

static irq_fn irq_vector[IRQ_COUNT] = {IRQ_UNSET};

void irq_enable(const enum IRQ mask) { __irq_mask(~mask); }

void irq_wait(const enum IRQ mask) { __irq_wait(mask); }

void irq_set_handler(const enum IRQ irq, const irq_fn handler) {
  irq_vector[irq] = handler;
}

usize *irq(usize *regs, const usize irqs) {
  for (usize i = 0; i < IRQ_COUNT; ++i) {
    if ((1 << i) & irqs) {
      irq_vector[i](regs);
    }
  }
  return regs;
}
