#include <hal/gpio.h>
#include <hal/irq.h>
#include <hal/time.h>
#include <stdio.h>

#define BTN_COUNT 5
#define DEBOUNCE_TIMEOUT 10

void print_event(const usize button, const enum DIGITAL_STATE state) {
  const char *BTN_NAME[BTN_COUNT] = {"UP", "DOWN", "LEFT", "RIGHT", "CENTER"};
  switch (state) {
  case LOW:
    printf("Button %s released\n", BTN_NAME[button]);
    break;
  case HIGH:
    printf("Button %s pressed\n", BTN_NAME[button]);
    break;
  }
}

void process_button(const usize button) {
  static u64 debounce[BTN_COUNT] = {};
  static enum DIGITAL_STATE btn_state[BTN_COUNT] = {};
  if (millis() - debounce[button] < DEBOUNCE_TIMEOUT) {
    return;
  }
  debounce[button] = millis();
  const enum DIGITAL_STATE new_state = get_btn((enum BUTTON)1 << button);
  if (btn_state[button] == new_state) {
    return;
  }
  btn_state[button] = new_state;
  print_event(button, new_state);
}

void button_event(const usize irq, union StackFrame *const stack_frame) {
  for (usize i = 0; i < BTN_COUNT; ++i) {
    process_button(i);
  }
}

void setup(void) {
  irq_set_handler(IRQ_BUTTON_EVENT, button_event);
  irq_set_enabled(IRQ_BUTTON_EVENT);
}

void loop(void) {
  static usize digit = 0;
  set_7segm(0b00000001 << (digit << 3));
  sleep(250);
  digit = (digit + 1) & 0b11;
}
