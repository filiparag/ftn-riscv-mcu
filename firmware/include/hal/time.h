#pragma once

#include <hal/types.h>

enum TIMER {
  TIMER0 = 0b00,
  TIMER1 = 0b01,
  TIMER2 = 0b10,
  TIMER3 = 0b11,
};

extern volatile u64 __counter_nanos;
extern volatile u64 __counter_micros;
extern volatile u64 __counter_millis;

extern volatile u8 __timer_reset;
extern volatile u8 __timer_select;
extern volatile u32 __timer_interval;

u64 millis(void);
u64 micros(void);
u64 nanos(void);

void timer_enable(const enum TIMER timer);
void timer_disable(const enum TIMER timer);
void timer_set_interval(const enum TIMER timer, const u64 interval_us);

void sleep(const u64 interval_ms);
