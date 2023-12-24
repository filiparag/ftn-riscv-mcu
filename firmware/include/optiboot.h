#pragma once

#include "types.h"

/* Custom Optiboot version */
#define OPTIBOOT_MAJVER 8
#define OPTIBOOT_MINVER 3
#define OPTIBOOT_CUSTOMVER 1

/* Arduino UNO */
#define SIGNATURE_0 0x1E
#define SIGNATURE_1 0x95
#define SIGNATURE_2 0x0F

extern const usize __sdram_start;
extern const usize __sdram_end;

void optiboot(void);
