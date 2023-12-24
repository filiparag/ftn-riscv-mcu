#pragma once

#include "types.h"

extern const volatile bool __uart_rx_ready;
extern const volatile bool __uart_tx_ready;
extern const volatile u8 __uart_rx;
extern volatile u8 __uart_tx;

void put_ch(const char character);
char get_ch(void);

void put_buff(const char *const buffer, const usize length);
void get_buff(char *const buffer, const usize length);

extern const volatile bool __debug_tx_ready;
extern volatile u8 __debug_tx;

void dbg_ch(const char character);
void dbg_buff(const char *const buffer, const usize length);
