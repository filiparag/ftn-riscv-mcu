#pragma once

#include "types.h"

#define IRQ_COUNT 32
#define IRQ_UNSET (irq_fn)0xFFFFFFFF

extern usize __irq_mask(const usize mask);
extern void __irq_wait(const usize mask);

typedef void (*irq_fn)(const usize);

enum IRQ {
  IRQ_ALL_DISABLED = 0,
  IRQ_TIMER0 = 1 << 0,
  IRQ_TIMER1 = 1 << 1,
  IRQ_TIMER2 = 1 << 2,
  IRQ_TIMER3 = 1 << 3,
  IRQ_UART_RX_READY = 1 << 4,
  IRQ_BUTTON_EVENT = 1 << 30,
  IRQ_SWITCH_EVENT = 1 << 31,
  IRQ_ALL_ENABLED = 0xFFFFFFFF,
};

usize irq_enable(const enum IRQ mask);
void irq_wait(const enum IRQ mask);
void irq_set_handler(const enum IRQ irq, const irq_fn handler);
