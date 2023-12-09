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
  BTN_UP = 0b00001,
  BTN_DOWN = 0b00010,
  BTN_LEFT = 0b00100,
  BTN_RIGHT = 0b01000,
  BTN_CENTER = 0b10000,
};

void set_led(const usize index, const enum DIGITAL_STATE state);

void set_hex(const u16 value);
void set_7segm(const u32 value);

enum DIGITAL_STATE get_btn(const enum BUTTON button);
enum DIGITAL_STATE get_sw(const usize index);
