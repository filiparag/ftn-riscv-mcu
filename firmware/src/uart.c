#include "../include/uart.h"

void put_ch(const char character) {
  while (!__uart_tx_ready)
    ;
  __uart_tx = character;
}

void get_ch(char *const character) {
  while (!__uart_rx_ready)
    ;
  *character = __uart_rx;
}

void put_buff(const char *const buffer, const usize length) {
  for (usize i = 0; i < length; ++i) {
    put_ch(buffer[i]);
  }
}

void get_buff(char *const buffer, const usize length) {
  for (usize i = 0; i < length; ++i) {
    get_ch(&buffer[i]);
  }
}
