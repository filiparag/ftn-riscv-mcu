#pragma once

#include "types.h"

extern const volatile bool __uart_rx_ready;
extern const volatile u8 __uart_rx;
extern volatile u8 __uart_tx;

void put_ch(const char character);
bool get_ch(char *const character);

void put_str(const char string[]);
usize get_str(char string[], const usize max_length, const bool break_line);
