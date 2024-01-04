#include "../include/gpio.h"
#include "../include/time.h"

int main(void) {
  for (;;) {
    set_hex((usize)millis() >> 10);
    sleep(250);
  }
  return 0;
}
