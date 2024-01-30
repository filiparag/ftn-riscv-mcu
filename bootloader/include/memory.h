#pragma once

#include <types.h>

/* Firmware memory region */
extern const usize __fw_start;
extern const usize __fw_end;

/* SDRAM region */
extern const usize __sdram_start;
extern const usize __sdram_end;

/* UART */
extern const volatile bool __uart0_rx_ready;
extern const volatile bool __uart0_tx_ready;
extern const volatile u8 __uart0_rx;
extern volatile u8 __uart0_tx;

extern const volatile bool __uart1_rx_ready;
extern const volatile bool __uart1_tx_ready;
extern const volatile u8 __uart1_rx;
extern volatile u8 __uart1_tx;

/* Runtime clock */
extern volatile u64 __counter_nanos;
extern volatile u64 __counter_micros;
extern volatile u64 __counter_millis;

/* GPIO */
extern volatile u16 __gpio_led_sem;
extern volatile u32 __gpio_7segm;

void zero_init_bram(void);
void zero_init_sdram(void);
