#include "../include/uart.h"

void put_ch(const char character) {
  while (!__uart_tx_ready)
    ;
  __uart_tx = character;
}

char get_ch(void) {
  while (!__uart_rx_ready)
    ;
  return __uart_rx;
}

void put_buff(const char *const buffer, const usize length) {
  for (usize i = 0; i < length; ++i) {
    put_ch(buffer[i]);
  }
}

void get_buff(char *const buffer, const usize length) {
  for (usize i = 0; i < length; ++i) {
    buffer[i] = get_ch();
  }
}

void dbg_ch(const char character) {
  while (!__debug_tx_ready)
    ;
  __debug_tx = character;
}

void dbg_buff(const char *const buffer, const usize length) {
  for (usize i = 0; i < length; ++i) {
    dbg_ch(buffer[i]);
  }
}
