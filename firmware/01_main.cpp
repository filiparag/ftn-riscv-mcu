#include <stdint.h>

extern volatile uint8_t __gpio_led;
extern volatile uint16_t __gpio_7segm_hex;
extern volatile uint32_t __gpio_7segm;
extern const volatile uint16_t __gpio_btn_sw;

extern volatile uint8_t __uart_tx;
extern const volatile uint8_t __uart_rx;

int main() {
  while (1) {
    __gpio_7segm_hex = 0xabcd;
    __gpio_led = __gpio_btn_sw & 0b0000011111111;
  }
  return 0;
}
