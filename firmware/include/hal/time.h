#pragma once

#include <hal/types.h>

enum TIMER {
  TIMER0 = 0b00,
  TIMER1 = 0b01,
  TIMER2 = 0b10,
  TIMER3 = 0b11,
};

u64 millis(void);
u64 micros(void);
u64 nanos(void);

void timer_set_enabled(const enum TIMER timer, const bool enabled);
bool timer_get_enabled(const enum TIMER timer);
void timer_set_interval(const enum TIMER timer, const u64 interval_us);

void sleep(const u64 interval_ms);
