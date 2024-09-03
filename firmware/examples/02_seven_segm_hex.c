#include <hal/gpio.h>
#include <hal/time.h>

static u16 counter = 1;

void setup(void) {}

void loop(void) {
  set_hex(counter);
  sleep(250);
  ++counter;
  if (counter == 10) {
    counter = 1;
  }
}
