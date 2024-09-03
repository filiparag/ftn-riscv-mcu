#include <hal/time.h>
#include <hal/uart.h>

#define HELLO_WORLD "Hello world\n"

void setup(void) {
  put_buff(UART1, HELLO_WORLD, sizeof(HELLO_WORLD));
  sleep(1000);
}

void loop(void) {
  for (usize n = 0; n < 10; ++n) {
    put_ch(UART1, '0' + n);
    sleep(250);
  }
  put_ch(UART1, '\n');
}
