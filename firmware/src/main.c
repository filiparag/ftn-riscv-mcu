#include "../include/gpio.h"
#include "../include/time.h"

int main(void) {
  for (;;) {
    const usize t = (usize)millis() >> 8;
    set_hex(t >> 1);
    sleep(50);
    for (usize c = 0; c < 8; ++c) {
      for (usize r = 0; r < 8; ++r) {
        const struct PIXEL p = {r - t % 3, c + t % 4, r > c};
        __gpio_disp[c][r] = p;
      }
    }
  }
  return 0;
}
