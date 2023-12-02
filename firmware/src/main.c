#include "../include/gpio.h"
#include "../include/uart.h"

int main() {
  while (1) {
    set_hex(0x1234);
    for (usize i = 0; i < 8; ++i) {
      __gpio_led = 1 << i;
      volatile usize k = 0;
      for (usize j = 0; j < 64000; ++j) {
        ++k;
      }
    }
    set_led(7, HIGH);
    static char name[255];
    if (!get_str(name, sizeof(name), true)) {
      continue;
    }
    if (get_sw(3)) {
      put_str("Hello ");
    } else {
      put_str("Hi ");
    }
    put_str(name);
    put_str("!\n");
    for (usize i = 0; i < 8; ++i) {
      __gpio_led = 0b10000000 >> i;
      volatile usize k = 0;
      for (usize j = 0; j < 64000; ++j) {
        ++k;
      }
    }
  }
  return 0;
}
