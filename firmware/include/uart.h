#pragma once

#include <types.h>

extern const volatile bool __uart0_rx_ready;
extern const volatile bool __uart0_tx_ready;
extern const volatile u8 __uart0_rx;
extern volatile u8 __uart0_tx;

extern const volatile bool __uart1_rx_ready;
extern const volatile bool __uart1_tx_ready;
extern const volatile u8 __uart1_rx;
extern volatile u8 __uart1_tx;

enum UART_PORT {
  UART0,
  UART1,
};

void put_ch(const enum UART_PORT port, const char character);
char get_ch(const enum UART_PORT port);

void put_buff(const enum UART_PORT port, const char *const buffer,
              const usize length);
void get_buff(const enum UART_PORT port, char *const buffer,
              const usize length);
