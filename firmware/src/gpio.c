#include "../include/gpio.h"

void set_led(const usize index, const enum DIGITAL_STATE state) {
  __gpio_led &= 1 << index;
}

void set_hex(const u16 value) { __gpio_7segm_hex = value; }

void set_7segm(const u32 value) { __gpio_7segm = value; }

enum DIGITAL_STATE get_btn(const enum BUTTON button) {
  return (__gpio_btn_sw & 1 << (button + 8)) ? HIGH : LOW;
}

enum DIGITAL_STATE get_sw(const usize index) {
  return (__gpio_btn_sw & 1 << index) ? HIGH : LOW;
}
