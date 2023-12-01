#include <stdint.h>

extern volatile uint8_t __gpio_led;
extern volatile uint16_t __gpio_7segm_hex;
extern volatile uint32_t __gpio_7segm;
extern const volatile uint16_t __gpio_btn_sw;

extern volatile uint8_t __uart_tx;
extern const volatile uint8_t __uart_rx;

const char message[] = "Hello world! This is a test...\r\n";
volatile int a = 0;


int main() {
  while (1) {
    __gpio_led = __gpio_btn_sw & 0b0000011111111;
    for (int i = 0; i < sizeof(message) / sizeof(char); ++i) {
      __uart_tx = message[i];
      if (message[i] >= 'A') {
        __gpio_7segm_hex = message[i];
      }
    }
    __uart_tx = a;
    if (__uart_rx != 0) {
      __gpio_7segm_hex = __uart_rx;
      for (int i = 0; i < 50000; ++i) {
        ++a;
      }
    }
  }
  return 0;
}
