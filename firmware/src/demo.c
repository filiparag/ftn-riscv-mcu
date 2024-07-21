#include <stdio.h>

#include <hal.h>

void redraw_led_matrix(const usize irq, union StackFrame *const stack_frame) {
  const usize t = millis();
  for (usize c = 0; c < 8; ++c) {
    for (usize r = 0; r < 8; ++r) {
      const struct PIXEL p = {r - 2 * (t >> 8) % 3, c + (t >> 9) % 4,
                              (t >> 7) % 5 < 3 ? r > c : c > r};
      __gpio_disp[c][r] = p;
    }
  }
}

void update_counter(const usize irq, union StackFrame *const stack_frame) {
  static u64 debounce = 0;
  static bool running = true;
  static usize counter = 1;
  if (irq == IRQ_TIMER1) {
    if (running) {
      ++counter;
    }
  } else if (irq == IRQ_BUTTON_EVENT && millis() - debounce > 100) {
    debounce = millis();
    if (get_btn(BTN_CENTER)) {
      running = !running;
    } else if (get_btn(BTN_UP)) {
      ++counter;
    } else if (get_btn(BTN_DOWN)) {
      --counter;
    }
  }
  set_hex(counter);
  set_led(0, running);
}

void semaphore(const usize irq, union StackFrame *const stack_frame) {
  static u8 state = 0;
  switch (state) {
  case 0:
    set_sem(SEM_RED, HIGH);
    set_sem(SEM_YELLOW, LOW);
    set_sem(SEM_GREEN, LOW);
    break;
  case 1:
    set_sem(SEM_RED, HIGH);
    set_sem(SEM_YELLOW, HIGH);
    set_sem(SEM_GREEN, LOW);
    break;
  case 2:
    set_sem(SEM_RED, LOW);
    set_sem(SEM_YELLOW, LOW);
    set_sem(SEM_GREEN, HIGH);
    break;
  case 3:
    set_sem(SEM_RED, LOW);
    set_sem(SEM_YELLOW, HIGH);
    set_sem(SEM_GREEN, LOW);
    break;
  }
  state = (state + 1) & 0b11;
}

void setup(void) {
  printf("Hello world!\n");
  set_7segm(0);
  irq_set_handler(IRQ_TIMER0, redraw_led_matrix);
  irq_set_handler(IRQ_TIMER1, update_counter);
  irq_set_handler(IRQ_BUTTON_EVENT, update_counter);
  irq_set_handler(IRQ_TIMER2, semaphore);
  timer_set_interval(TIMER0, 20000);
  timer_set_interval(TIMER1, 100000);
  timer_set_interval(TIMER2, 1000000);
  timer_enable(TIMER0);
  timer_enable(TIMER1);
  timer_enable(TIMER2);
  irq_enable(IRQ_TIMER0 | IRQ_TIMER1 | IRQ_TIMER2 | IRQ_BUTTON_EVENT);
}

void loop(void) {
  const usize s = millis() / 1000;
  const usize ms = millis() % 1000;
  printf("Runtime is %u.%03u s...\n", (unsigned int)s, (unsigned int)ms);
  sleep(1000 - ms);
}
