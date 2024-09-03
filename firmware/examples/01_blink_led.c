#include <hal/gpio.h>
#include <hal/time.h>

const usize led_index = 0;
static enum DIGITAL_STATE led_state = HIGH;

void setup(void) {}

void loop(void) {
  set_led(led_index, led_state);
  sleep(1000);
  if (led_state == LOW) {
    led_state = HIGH;
  } else {
    led_state = LOW;
  }
}
