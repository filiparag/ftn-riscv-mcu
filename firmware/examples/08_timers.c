#include <hal/gpio.h>
#include <hal/irq.h>
#include <hal/time.h>
#include <stdio.h>

#define SECONDS_IN_MINUTE 60
#define MINUTES_IN_HOUR 60
#define HOURS_IN_DAY 24

#define MICROSECOND_IN_SECOND (u64)1000000
#define MICROSECOND_IN_MINUTE (SECONDS_IN_MINUTE * MICROSECOND_IN_SECOND)
#define MICROSECOND_IN_HOUR (MINUTES_IN_HOUR * MICROSECOND_IN_MINUTE)

static volatile usize seconds = 0;
static volatile usize minutes = 0;
static volatile usize hours = 0;

void print_clock(const usize irq, union StackFrame *const stack_frame) {
  printf("Current time is %02i:%02i:%02i\n", hours, minutes, seconds);
}

void increment_seconds(const usize irq, union StackFrame *const stack_frame) {
  if (seconds < SECONDS_IN_MINUTE - 1) {
    ++seconds;
  } else {
    seconds = 0;
  }
}

void increment_minutes(const usize irq, union StackFrame *const stack_frame) {
  if (minutes < MINUTES_IN_HOUR - 1) {
    ++minutes;
  } else {
    minutes = 0;
  }
}

void increment_hours(const usize irq, union StackFrame *const stack_frame) {
  if (hours < HOURS_IN_DAY - 1) {
    ++hours;
  } else {
    hours = 0;
  }
}

void setup(void) {
  timer_set_interval(TIMER0, MICROSECOND_IN_SECOND * 2);
  timer_set_interval(TIMER1, MICROSECOND_IN_SECOND);
  timer_set_interval(TIMER2, MICROSECOND_IN_MINUTE);
  timer_set_interval(TIMER3, MICROSECOND_IN_HOUR);
  irq_set_handler(IRQ_TIMER0, print_clock);
  irq_set_handler(IRQ_TIMER1, increment_seconds);
  irq_set_handler(IRQ_TIMER2, increment_minutes);
  irq_set_handler(IRQ_TIMER3, increment_hours);
  irq_set_enabled(IRQ_TIMER0 | IRQ_TIMER1 | IRQ_TIMER2 | IRQ_TIMER3);
  timer_set_enabled(TIMER0, true);
  timer_set_enabled(TIMER1, true);
  timer_set_enabled(TIMER2, true);
  timer_set_enabled(TIMER3, true);
}

void loop(void) {}
