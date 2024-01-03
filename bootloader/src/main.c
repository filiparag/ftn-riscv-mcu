
#include "../include/optiboot.h"

extern volatile u32 __gpio_7segm;
extern void __start(void);

int main(void) {
  for (;;) {
    __gpio_7segm = 0b00011111011111100111111000001111;
    optiboot();
    __start();
  }
  return 0;
}
