#include "../include/optiboot.h"
#include "../include/memory.h"

void put_ch(const char character) {
  while (!__uart_tx_ready)
    ;
  __uart_tx = character;
}

char get_ch(void) {
  while (!__uart_rx_ready)
    ;
  return __uart_rx;
}

void sleep(const u64 interval_ms) {
  const u64 start = __counter_millis;
  while (__counter_millis - start < interval_ms)
    ;
}

void flash_led(void) {
  for (usize i = 0; i < LED_FLASH_COUNT; ++i) {
    __gpio_led = 1;
    sleep(LED_FLASH_INTERVAL);
    __gpio_led = 0;
    sleep(LED_FLASH_INTERVAL);
  }
}

u8 get_length(void) {
  u8 length;
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
  u16 lo, hi;
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
  volatile usize *const bram = (usize *)&__fw_start;
  const usize page_start = address << 1;
  for (usize byte = 0; byte < length; ++byte) {
    const usize offset = page_start + byte;
    *(bram + offset) = get_ch();
  }
  verify_space();
}

void stk_read_page(const u16 address) {
  u8 length = get_length();
  get_ch(); // desttype
  verify_space();
  const volatile usize *const bram = (usize *)&__fw_start;
  const usize page_start = address << 1;
  for (usize byte = 0; byte < length; ++byte) {
    const usize offset = page_start + byte;
    put_ch(*(bram + offset));
  }
}

void stk_read_sign(void) {
  verify_space();
  put_ch(SIGNATURE_0);
  put_ch(SIGNATURE_1);
  put_ch(SIGNATURE_2);
}

void optiboot(void) {
  flash_led();
  u16 address;
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
