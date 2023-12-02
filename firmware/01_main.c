#include "gpio.h"
#include "types.h"
#include "uart.h"

void putled(const usize index, const enum DIGITAL_STATE state) {
  __gpio_led &= 1 << index;
}

void puthex(const u16 value) { __gpio_7segm_hex = value; }

void put7segm(const u32 value) { __gpio_7segm = value; }

enum DIGITAL_STATE getbtn(const enum BUTTON button) {
  return (__gpio_btn_sw & 1 << (button + 8)) ? HIGH : LOW;
}

enum DIGITAL_STATE getsw(const usize index) {
  return (__gpio_btn_sw & 1 << index) ? HIGH : LOW;
}

void putch(const char character) { __uart_tx = character; }

bool getch(char *const character) {
  if (__uart_rx_ready) {
    *character = __uart_rx;
    return 1;
  } else {
    return 0;
  }
}

void putstr(const char string[], const usize length) {
  for (usize i = 0; i < length; ++i) {
    __uart_tx = string[i];
  }
}

usize getstr(char string[], const usize max_length) {
  usize i = 0;
  while (i < max_length) {
    while (!__uart_rx_ready) {
    }
    const char c = __uart_rx;
    if (c == '\n') {
      break;
    }
    string[i] = c;
    ++i;
  }
  if (i < max_length) {
    string[i] = '\0';
  }
  return i;
}

int main() {
  while (1) {
    puthex(0x1234);
    putled(7, HIGH);
    usize len = 0;
    char name[255];
    len = getstr(name, sizeof(name));
    if (getsw(3)) {
      putstr("Hello ", 6);
    } else {
      putstr("Hi ", 3);
    }
    putstr(name, len);
    putstr("!\n", 2);
  }
  return 0;
}
