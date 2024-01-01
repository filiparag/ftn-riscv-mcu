#pragma once

#include "stk500.h"
#include "types.h"

/* GPIO */
extern volatile u8 __gpio_led;

/* UART */
extern const volatile bool __uart_rx_ready;
extern const volatile bool __uart_tx_ready;
extern const volatile u8 __uart_rx;
extern volatile u8 __uart_tx;

/* Runtime clock */
extern volatile u64 __counter_nanos;
extern volatile u64 __counter_micros;
extern volatile u64 __counter_millis;

/* Custom Optiboot version */
#define OPTIBOOT_MAJVER 8
#define OPTIBOOT_MINVER 3
#define OPTIBOOT_CUSTOMVER 1

/* Arduino UNO */
#define SIGNATURE_0 0x1E
#define SIGNATURE_1 0x95
#define SIGNATURE_2 0x0F

/* Debug */
#define LED_FLASH_COUNT 2
#define LED_FLASH_INTERVAL 150

extern const usize __sdram_start;
extern const usize __sdram_end;

void optiboot(void);
