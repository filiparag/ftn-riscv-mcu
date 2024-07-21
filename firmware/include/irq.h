#pragma once

#include <types.h>

#define IRQ_COUNT 32
#define IRQ_UNSET (irq_fn)0xFFFFFFFF

extern usize __irq_mask(const usize mask);
extern void __irq_wait(const usize mask);

extern void __ecall();

struct StackFrameRegs {
  usize pc, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15,
      x16, x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30,
      x31;
};

struct StackFrameABI {
  usize pc, ra, sp, gp, tp, t0, t1, t2, fp, s1, a0, a1, a2, a3, a4, a5, a6, a7,
      s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, t3, t4, t5, t6;
};

union StackFrame {
  struct StackFrameRegs regs;
  struct StackFrameABI abi;
};

typedef void (*irq_fn)(const usize, union StackFrame *const);

enum IRQ {
  IRQ_NONE = 0,
  IRQ_INT_TIMER = 1 << 0,
  IRQ_ECALL = 1 << 1,
  IRQ_BUS_ERROR = 1 << 2,
  IRQ_TIMER0 = 1 << 4,
  IRQ_TIMER1 = 1 << 5,
  IRQ_TIMER2 = 1 << 6,
  IRQ_TIMER3 = 1 << 7,
  IRQ_UART_RX_READY = 1 << 8,
  IRQ_UART_TX_READY = 1 << 9,
  IRQ_BUTTON_EVENT = 1 << 30,
  IRQ_SWITCH_EVENT = 1 << 31,
  IRQ_ALL = 0xFFFFFFFF,
};

usize irq_enable(const enum IRQ mask);
void irq_wait(const enum IRQ mask);
void irq_set_handler(const enum IRQ irq, const irq_fn handler);
