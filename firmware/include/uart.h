#pragma once

#include "types.h"

extern const volatile bool __uart_rx_recv;
extern const volatile u8 __uart_rx;
extern volatile u8 __uart_tx;

void put_ch(const char character);
bool get_ch(char *const character);

void put_buff(const char *const buffer, const usize length);
void get_buff(char *const buffer, const usize length);
