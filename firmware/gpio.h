#pragma once

#include "types.h"
#include "uart.h"

extern volatile u8 __gpio_led;
extern volatile u16 __gpio_7segm_hex;
extern volatile u32 __gpio_7segm;
extern const volatile u16 __gpio_btn_sw;

enum DIGITAL_STATE {
  LOW = 0,
  HIGH = 1,
};

enum BUTTON {
  UP = 0b00001,
  DOWN = 0b00010,
  LEFT = 0b00100,
  RIGHT = 0b01000,
  CENTER = 0b10000,
};
