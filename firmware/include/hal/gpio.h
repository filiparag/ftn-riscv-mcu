#pragma once

#include <hal/types.h>
#include <hal/uart.h>

#define DISP_ROWS 8
#define DISP_COLS 8

struct PIXEL {
  usize red : 1;
  usize green : 1;
  usize blue : 1;
};

enum DIGITAL_STATE {
  LOW = 0,
  HIGH = 1,
};

enum SEMAPHORE {
  SEM_RED = 1 << 10,
  SEM_YELLOW = 1 << 9,
  SEM_GREEN = 1 << 8,
};

enum BUTTON {
  BTN_UP = 0b1,
  BTN_DOWN = 0b10,
  BTN_LEFT = 0b100,
  BTN_RIGHT = 0b1000,
  BTN_CENTER = 0b10000,
};

void set_led(const usize index, const enum DIGITAL_STATE state);
void set_sem(const enum SEMAPHORE color, const enum DIGITAL_STATE state);

void set_hex(const u16 value);
void set_7segm(const u32 value);

enum DIGITAL_STATE get_btn(const enum BUTTON button);
enum DIGITAL_STATE get_sw(const usize index);
