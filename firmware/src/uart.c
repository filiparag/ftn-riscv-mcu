#include "../include/uart.h"

void put_ch(const char character) { __uart_tx = character; }

bool get_ch(char *const character) {
  if (__uart_rx_recv) {
    *character = __uart_rx;
    return 1;
  } else {
    return 0;
  }
}

void put_buff(const char *const buffer, const usize length) {
  for (usize i = 0; i < length; ++i) {
    __uart_tx = buffer[i];
  }
}

void get_buff(char *const buffer, const usize length) {
  for (usize i = 0; i < length; ++i) {
    while (!__uart_rx_recv)
      ;
    buffer[i] = __uart_rx;
  }
}
