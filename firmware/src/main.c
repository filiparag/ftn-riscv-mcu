#include "../include/gpio.h"
#include "../include/irq.h"
#include "../include/time.h"
#include "../include/uart.h"

void move(const usize irqs) {
  static u8 row = 0, col = 0, row_s = 0xFF, col_s = 0xFF;
  if (get_btn(BTN_UP)) {
    row -= 1;
    put_buff("UP\n\0", 3);
  } else if (get_btn(BTN_DOWN)) {
    put_buff("DOWN\n\0", 5);
    row += 1;
  } else if (get_btn(BTN_LEFT)) {
    put_buff("LEFT\n\0", 5);
    col -= 1;
  } else if (get_btn(BTN_RIGHT)) {
    put_buff("RIGHT\n\0", 6);
    col += 1;
  }
  col = col < 8 ? col : 0;
  row = row < 8 ? row : 0;
  if (get_btn(BTN_CENTER)) {
    put_buff("CENTER\n\0", 7);
    row_s = row;
    col_s = col;
  }
  set_hex(((u16)row << 8) | col);
  for (usize c = 0; c < 8; ++c) {
    for (usize r = 0; r < 8; ++r) {
      const bool point = r == row && c == col;
      const bool last = r == row_s && c == col_s;
      if ((point || last) && (__gpio_btn_sw & 0b10) == 0) {
        const struct PIXEL p = {0, point, last};
        __gpio_disp[c][r] = p;
      } else if (__gpio_btn_sw & 0b1) {
        const struct PIXEL p = {1, 0, 0};
        __gpio_disp[c][r] = p;
      }
    }
  }
  sleep(100);
}

void snake(const usize irqs) {
  static u8 value = 0;
  ++value;
  __gpio_led = value;
}

int main() {

  set_7segm(0b00110111010011110000111001111110);
  put_buff("Hello world!\n\0", 13);

  for (usize c = 0; c < 8; ++c) {
    for (usize r = 0; r < 8; ++r) {
      const struct PIXEL p = {r, c, r > c};
      __gpio_disp[c][r] = p;
    }
  }

  irq_set_handler(IRQ_TIMER0, snake);
  irq_set_handler(IRQ_BUTTON_EVENT, move);
  irq_set_handler(IRQ_SWITCH_EVENT, move);
  irq_enable(IRQ_BUTTON_EVENT | IRQ_SWITCH_EVENT | IRQ_TIMER0);
  timer_set_interval(TIMER0, 100000);
  timer_enable(TIMER0);

  while (1)
    ;
  return 0;
}
