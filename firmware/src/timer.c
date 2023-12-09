#include "../include/time.h"

u32 millis(void) { return __counter_millis; }

u32 micros(void) { return __counter_micros; }

u64 nanos(void) { return __counter_nanos; }

void timer_enable(const enum TIMER timer) {
  __timer_reset = (__timer_reset & ~(1 << timer));
}

void timer_disable(const enum TIMER timer) {
  __timer_reset = (__timer_reset & ~(1 << timer)) | (1 << timer);
}

void timer_set_interval(const enum TIMER timer, const u64 interval) {
  __timer_select = timer;
  __timer_interval = interval;
}
