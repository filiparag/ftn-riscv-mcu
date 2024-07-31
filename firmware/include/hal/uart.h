#pragma once

#include <hal/types.h>

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
