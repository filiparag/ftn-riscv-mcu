#pragma once

#include "types.h"

/* Firmware memory region */
extern const usize __fw_start;
extern const usize __fw_end;

/* SDRAM region */
extern const usize __sdram_start;
extern const usize __sdram_end;

/* UART */
extern const volatile bool __uart_rx_ready;
extern const volatile bool __uart_tx_ready;
extern const volatile u8 __uart_rx;
extern volatile u8 __uart_tx;

/* Runtime clock */
extern volatile u64 __counter_nanos;
extern volatile u64 __counter_micros;
extern volatile u64 __counter_millis;

/* GPIO */
extern volatile u8 __gpio_led;
extern volatile u32 __gpio_7segm;

void init_ram(void);
