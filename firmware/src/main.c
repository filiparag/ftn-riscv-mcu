#include <stdio.h>

#include "../include/gpio.h"
#include "../include/time.h"

extern void __libc_init_array(void);
extern const usize __sdram_start;

int main(void) {
  usize ls = 0;
  for (;;) {
    const usize t = millis();
    const usize s = t >> 10;
    if (ls != s) {
      printf("Runtime = %4i seconds\n", s);
      ls = s;
    }
    set_hex(s);
    for (usize c = 0; c < 8; ++c) {
      for (usize r = 0; r < 8; ++r) {
        const struct PIXEL p = {r - 2 * (t >> 8) % 3, c + (t >> 9) % 4,
                                (t >> 7) % 5 < 3 ? r > c : c > r};
        __gpio_disp[c][r] = p;
      }
    }
    sleep(10);
  }
  return 0;
}
