#include "../include/optiboot.h"
#include "../include/stk500.h"
#include "../include/time.h"
#include "../include/uart.h"

u8 get_length(void) {
  static u8 length;
  length = get_ch() << 8;
  length |= get_ch();
  return length;
}

void verify_space(void) {
  if (get_ch() != CRC_EOP) {
    sleep(16);
  }
  put_ch(STK_INSYNC);
}

void get_n_ch(const usize count) {
  for (usize i = 0; i < count; ++i) {
    get_ch();
  }
  verify_space();
}

void init_sdram(void) {
  volatile static usize *sdram = (usize *)&__sdram_start;
  for (; sdram < &__sdram_end; ++sdram) {
    *sdram = 0;
  }
}

void stk_get_parameter(void) {
  unsigned char which = get_ch();
  verify_space();
  usize version =
      256 * (OPTIBOOT_MAJVER + OPTIBOOT_CUSTOMVER) + OPTIBOOT_MINVER;
  if (which == STK_SW_MINOR) {
    put_ch(version & 0xFF);
  } else if (which == STK_SW_MAJOR) {
    put_ch(version >> 8);
  } else {
    put_ch(0x03);
  }
}

void stk_load_address(u16 *const address) {
  static u16 lo, hi;
  lo = get_ch();
  hi = get_ch() << 8;
  *address = lo | hi;
  verify_space();
}

void stk_univeral(void) {
  get_n_ch(4);
  put_ch(0x00);
}

void stk_prog_page(const u16 address) {
  u8 length = get_length();
  get_ch(); // desttype
  volatile static usize *const sdram = (usize *)&__sdram_start;
  const usize page_start = address << 1;
  for (usize byte = 0; byte < length; ++byte) {
    const usize offset = page_start + byte;
    *(sdram + offset) = get_ch();
  }
  verify_space();
}

void stk_read_page(const u16 address) {
  u8 length = get_length();
  get_ch(); // desttype
  verify_space();
  const static volatile usize *const sdram = (usize *)&__sdram_start;
  const usize page_start = address << 1;
  for (usize byte = 0; byte < length; ++byte) {
    const usize offset = page_start + byte;
    put_ch(*(sdram + offset));
  }
}

void stk_read_sign(void) {
  verify_space();
  put_ch(SIGNATURE_0);
  put_ch(SIGNATURE_1);
  put_ch(SIGNATURE_2);
}

void optiboot(void) {
  init_sdram();
  sleep(1000);
  static u16 address;
  for (;;) {
    switch (get_ch()) {
    case STK_GET_PARAMETER:
      stk_get_parameter();
      break;
    case STK_SET_DEVICE:
      get_n_ch(20);
      break;
    case STK_SET_DEVICE_EXT:
      get_n_ch(5);
      break;
    case STK_LEAVE_PROGMODE:
      verify_space();
      put_ch(STK_OK);
      return;
    case STK_LOAD_ADDRESS:
      stk_load_address(&address);
      break;
    case STK_UNIVERSAL:
      stk_univeral();
      break;
    case STK_PROG_PAGE:
      stk_prog_page(address);
      break;
    case STK_READ_PAGE:
      stk_read_page(address);
      break;
    case STK_READ_SIGN:
      stk_read_sign();
      break;
    default:
      verify_space();
    }
    put_ch(STK_OK);
  }
}
