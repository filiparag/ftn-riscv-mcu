#include <hal/gpio.h>

extern const volatile u16 __gpio_btn_sw;

extern volatile u16 __gpio_led_sem;

extern volatile u16 __gpio_7segm_hex;
extern volatile u32 __gpio_7segm;

extern volatile struct PIXEL __gpio_disp[DISP_ROWS][DISP_COLS];

void set_led(const usize index, const enum DIGITAL_STATE state) {
  if (index < 8) {
    const u16 mask = 1 << index;
    __gpio_led_sem = (__gpio_led_sem & ~mask) | ((state == HIGH) << index);
  }
}

void set_sem(const enum SEMAPHORE color, const enum DIGITAL_STATE state) {
  __gpio_led_sem = (__gpio_led_sem & ~color) | ((state == HIGH) ? color : 0);
}

void set_hex(const u16 value) { __gpio_7segm_hex = value; }

void set_7segm(const u32 value) { __gpio_7segm = value; }

enum __attribute__((always_inline)) DIGITAL_STATE
get_btn(const enum BUTTON button) {
  return (__gpio_btn_sw >> 8 & button) ? HIGH : LOW;
}

enum __attribute__((always_inline)) DIGITAL_STATE get_sw(const usize index) {
  return (__gpio_btn_sw & 1 << index) ? HIGH : LOW;
}
