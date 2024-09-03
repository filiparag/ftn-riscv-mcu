#include <hal/gpio.h>
#include <hal/time.h>

static u32 symbol = 0b00000001;

void setup(void) {}

void loop(void) {
  set_7segm(symbol);
  sleep(100);
  symbol <<= 1;
  if (symbol == 0) {
    symbol = 0b00000001;
  }
}
