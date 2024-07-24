#include <hal/time.h>

u64 millis(void) { return __counter_millis; }

u64 micros(void) { return __counter_micros; }

u64 nanos(void) { return __counter_nanos; }

void timer_set_enabled(const enum TIMER timer, const bool enabled) {
  if (enabled) {
    __timer_reset = (__timer_reset & ~(1 << timer));
  } else {
    __timer_reset = (__timer_reset & ~(1 << timer)) | (1 << timer);
  }
}

bool timer_get_enabled(const enum TIMER timer) {
  return !((__timer_reset >> timer) & 1);
}

void timer_set_interval(const enum TIMER timer, const u64 interval_us) {
  __timer_select = timer;
  __timer_interval = interval_us;
}

void sleep(const u64 interval_ms) {
  const u64 start = millis();
  while (millis() - start < interval_ms)
    ;
}
