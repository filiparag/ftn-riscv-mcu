#include "../include/uart.h"

void put_ch(const char character) { __uart_tx = character; }

bool get_ch(char *const character) {
  if (__uart_rx_ready) {
    *character = __uart_rx;
    return 1;
  } else {
    return 0;
  }
}

void put_str(const char string[]) {
  usize i = 0;
  while (string[i] != '\0') {
    __uart_tx = string[i];
    ++i;
  }
}

usize get_str(char string[], const usize max_length, const bool break_line) {
  usize i = 0;
  while (i < max_length - 1) {
    while (!__uart_rx_ready)
      ;
    const char c = __uart_rx;
    if (break_line && c == '\n') {
      break;
    }
    string[i] = c;
    ++i;
  }
  string[i] = '\0';
  return i;
}
