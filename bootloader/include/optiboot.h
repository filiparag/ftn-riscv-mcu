#pragma once

#include "stk500.h"
#include "types.h"

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

void optiboot(void);
