
#include "../include/memory.h"
#include "../include/optiboot.h"

extern void __exit(void);

int main(void) {
  for (;;) {
    init_ram();
    __gpio_7segm = 0b00011111011111100111111000001111;
    optiboot();
    __gpio_7segm = 0;
    __exit();
  }
  return 0;
}
