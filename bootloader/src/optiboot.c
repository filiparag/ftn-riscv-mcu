#include <memory.h>
#include <optiboot.h>

static u64 time_start_millis;
static bool timeout_enabled;

void sleep(const u64 interval_ms) {
  const u64 start = __counter_millis;
  while (__counter_millis - start < interval_ms)
    ;
}

void flash_led(const usize count) {
  for (usize i = 0; i < count; ++i) {
    __gpio_led_sem = 1;
    sleep(LED_FLASH_INTERVAL);
    __gpio_led_sem = 0;
    sleep(LED_FLASH_INTERVAL);
  }
}

void exit_optiboot(void) {
  flash_led(LED_FLASH_COUNT_TIMEOUT);
  __gpio_7segm = HEX_EMPTY;
  __exit();
}

void put_ch(const char character) {
  while (!__uart0_tx_ready)
    ;
  __uart0_tx = character;
}

#ifdef DEBUG_OVER_UART1

void put_dbg(const char *const buffer) {
  char *character = (char *)buffer;
  while (*character != '\0') {
    while (!__uart1_tx_ready)
      ;
    __uart1_tx = *character;
    ++character;
  }
}

void put_dbg_num(const usize number, const usize base) {
  char buffer[32];
  usize n = number;
  usize d = 0;
  do {
    char a = n % base;
    buffer[d] = (a < 10 ? '0' + a : 'A' + a - 10);
    n /= base;
    ++d;
  } while (n != 0);
  switch (base) {
  case 2:
    while (d < 8) {
      buffer[d] = '0';
      ++d;
    }
    break;
  case 16:
    while (d < 2) {
      buffer[d] = '0';
      ++d;
    }
    break;
  }
  for (usize i = 0; i < d / 2; ++i) {
    char a = buffer[i];
    buffer[i] = buffer[d - i - 1];
    buffer[d - i - 1] = a;
  }
  buffer[d] = '\0';
  put_dbg(buffer);
}

#endif

char get_ch(void) {
  while (!__uart0_rx_ready) {
    if (timeout_enabled && __counter_millis - time_start_millis >= TIMEOUT_MS) {
#ifdef DEBUG_OVER_UART1
      put_dbg("\nOptiboot timeout at ");
      put_dbg_num((usize)__counter_millis, 10);
      put_dbg(" ms.\n");
#endif
      exit_optiboot();
    }
  }
  timeout_enabled = false;
  return __uart0_rx;
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
  const usize page_start = address << 1;
#ifdef DEBUG_OVER_UART1
  put_dbg("Page start: ");
  put_dbg_num(page_start, 16);
  put_dbg("\n");
#endif
  u8 length = get_length();
  get_ch(); // desttype
  volatile char *const bram = (char *)&__fw_start;
  for (usize byte = 0; byte < length; ++byte) {
    const usize offset = page_start + byte;
    const u8 value = get_ch();
    *(bram + offset) = value;
#ifdef DEBUG_OVER_UART1
    put_dbg_num(value, 16);
    if (byte > 0 && byte % 4 == 3) {
      put_dbg("\n");
    } else {
      put_dbg(" ");
    }
#endif
  }
  verify_space();
}

void stk_read_page(const u16 address) {
  u8 length = get_length();
  get_ch(); // desttype
  verify_space();
  const volatile char *const bram = (char *)&__fw_start;
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
  __gpio_7segm = HEX_BOOT;
  flash_led(LED_FLASH_COUNT_START);
  time_start_millis = __counter_millis;
  timeout_enabled = true;
#ifdef DEBUG_OVER_UART1
  put_dbg("\n\nOptiboot started at ");
  put_dbg_num((usize)__counter_millis, 10);
  put_dbg(" ms.\n");
#endif
  u16 address;
  for (;;) {
    switch (get_ch()) {
    case STK_GET_PARAMETER:
      stk_get_parameter();
#ifdef DEBUG_OVER_UART1
      put_dbg("STK_GET_PARAMETER\n");
#endif
      break;
    case STK_SET_DEVICE:
      get_n_ch(20);
#ifdef DEBUG_OVER_UART1
      put_dbg("STK_SET_DEVICE\n");
#endif
      break;
    case STK_SET_DEVICE_EXT:
      get_n_ch(5);
#ifdef DEBUG_OVER_UART1
      put_dbg("STK_SET_DEVICE_EXT\n");
#endif
      break;
    case STK_LEAVE_PROGMODE:
      verify_space();
      put_ch(STK_OK);
#ifdef DEBUG_OVER_UART1
      put_dbg("STK_LEAVE_PROGMODE\n");
#endif
      exit_optiboot();
      return;
    case STK_LOAD_ADDRESS:
      stk_load_address(&address);
#ifdef DEBUG_OVER_UART1
      put_dbg("STK_LOAD_ADDRESS ");
      put_dbg_num(address, 16);
      put_dbg("\n");
#endif
      break;
    case STK_UNIVERSAL:
      stk_univeral();
#ifdef DEBUG_OVER_UART1
      put_dbg("STK_UNIVERSAL\n");
#endif
      break;
    case STK_PROG_PAGE:
      stk_prog_page(address);
#ifdef DEBUG_OVER_UART1
      put_dbg("STK_PROG_PAGE ");
      put_dbg_num(address, 16);
      put_dbg("\n");
#endif
      break;
    case STK_READ_PAGE:
      stk_read_page(address);
#ifdef DEBUG_OVER_UART1
      put_dbg("STK_READ_PAGE ");
      put_dbg_num(address, 16);
      put_dbg("\n");
#endif
      break;
    case STK_READ_SIGN:
      stk_read_sign();
#ifdef DEBUG_OVER_UART1
      put_dbg("STK_READ_SIGN\n");
#endif
      break;
    default:
      verify_space();
#ifdef DEBUG_OVER_UART1
      put_dbg("STK_DEFAULT\n");
#endif
    }
    put_ch(STK_OK);
  }
}
