#include "../include/gpio.h"
#include "../include/optiboot.h"

int main(void) {
  set_7segm(0b01111110011001110000111100110000);
  optiboot();
  for (;;) {
    set_7segm(0b00001110011001110000010101011011);
  }
  return 0;
}
