#include <hal/gpio.h>

void setup(void) {}

void set_all_leds(const enum DIGITAL_STATE state) {
  for (usize i = 0; i < 8; ++i) {
    set_led(i, state);
  }
}

void loop(void) {
  if (get_btn(BTN_CENTER)) {
    set_all_leds(HIGH);
  } else {
    for (usize pair = 0; pair < 8; ++pair) {
      const enum DIGITAL_STATE switch_state = get_sw(pair);
      set_led(pair, switch_state);
    }
  }
}
