#pragma once

#include <stk500.h>
#include <types.h>

extern void __exit(void);

/* Custom Optiboot version */
#define OPTIBOOT_MAJVER 8
#define OPTIBOOT_MINVER 3
#define OPTIBOOT_CUSTOMVER 1

/* Arduino UNO */
#define SIGNATURE_0 0x1E
#define SIGNATURE_1 0x95
#define SIGNATURE_2 0x0F

/* Debug */
#define LED_FLASH_COUNT_START 2
#define LED_FLASH_COUNT_DONE 3
#define LED_FLASH_COUNT_TIMEOUT 1
#define LED_FLASH_INTERVAL 150

#define TIMEOUT_MS 2500

void optiboot(void);
