#include <uart.h>

void put_ch(const enum UART_PORT port, const char character) {
  switch (port) {
  case UART0:
    while (!__uart0_tx_ready)
      ;
    __uart0_tx = character;
    break;
  case UART1:
    while (!__uart1_tx_ready)
      ;
    __uart1_tx = character;
    break;
  }
}

char get_ch(const enum UART_PORT port) {
  switch (port) {
  case UART0:
    while (!__uart0_rx_ready)
      ;
    return __uart0_rx;

  case UART1:
    while (!__uart1_rx_ready)
      ;
    return __uart1_rx;
  default:
    return '\0';
  }
}

void put_buff(const enum UART_PORT port, const char *const buffer,
              const usize length) {
  for (usize i = 0; i < length; ++i) {
    put_ch(port, buffer[i]);
  }
}

void get_buff(const enum UART_PORT port, char *const buffer,
              const usize length) {
  for (usize i = 0; i < length; ++i) {
    buffer[i] = get_ch(port);
  }
}
