#include <hal/gpio.h>

#define RGB(r, g, b) (struct PIXEL){r, g, b};

#define COLOR_RED RGB(1, 0, 0)
#define COLOR_GREEN RGB(0, 1, 0)
#define COLOR_BLUE RGB(0, 0, 1)

extern volatile struct PIXEL __gpio_disp[DISP_COLS][DISP_ROWS];

void setup(void) {
  for (usize row = 0; row < DISP_ROWS; ++row) {
    for (usize col = 0; col < DISP_COLS; ++col) {
      if (row < 2) {
        __gpio_disp[col][row] = COLOR_RED;
      } else if (row < 6) {
        __gpio_disp[col][row] = COLOR_BLUE;
      } else {
        __gpio_disp[col][row] = COLOR_GREEN;
      }
    }
  }
}

void loop(void) {}
