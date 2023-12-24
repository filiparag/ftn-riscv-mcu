#include "../include/gpio.h"
#include "../include/stk500.h"
#include "../include/time.h"
#include "../include/uart.h"

extern const usize __prog_start;
extern const usize __prog_end;

#define OPTIBOOT_MAJVER 8
#define OPTIBOOT_MINVER 3
#define OPTIBOOT_CUSTOMVER 11

#define SIGNATURE_0 0x1E
#define SIGNATURE_1 0x95
#define SIGNATURE_2 0x0F

/*
 * optiboot uses several "address" variables that are sometimes byte pointers,
 * sometimes word pointers. sometimes 16bit quantities, and sometimes built
 * up from 8bit input characters.  avr-gcc is not great at optimizing the
 * assembly of larger words from bytes, but we can use the usual union to
 * do this manually.  Expanding it a little, we can also get rid of casts.
 */
typedef union {
  uint8_t *bptr;
  uint16_t *wptr;
  uint16_t word;
  uint8_t bytes[2];
} addr16_t;

u8 get_length() {
  u8 length;
  length = get_ch() << 8;
  length |= get_ch();
  return length;
}

void verify_space() {
  if (get_ch() != CRC_EOP) {
    // watchdogConfig(WATCHDOG_16MS); // shorten WD timeout
    // while (1) // and busy-loop so that WD causes
    // ;       //  a reset and app start.
    sleep(16);
    // __reset();
  }
  put_ch(STK_INSYNC);
}

void get_n_ch(const usize count) {
  for (usize i = 0; i < count; ++i) {
    get_ch();
  }
  verify_space();
}

void stk_get_parameter() {
  unsigned char which = get_ch();
  verify_space();
  /*
   * Send optiboot version as "SW version"
   * Note that the references to memory are optimized away.
   */
  usize version =
      256 * (OPTIBOOT_MAJVER + OPTIBOOT_CUSTOMVER) + OPTIBOOT_MINVER;
  if (which == STK_SW_MINOR) {
    put_ch(version & 0xFF);
  } else if (which == STK_SW_MAJOR) {
    put_ch(version >> 8);
  } else {
    /*
     * GET PARAMETER returns a generic 0x03 reply for
     * other parameters - enough to keep Avrdude happy
     */
    put_ch(0x03);
  }
}

void stk_prog_page(const u16 address) {
  set_hex(0x0aaa);
  u8 length = get_length();
  volatile usize *sdram = (usize *)&__prog_start;
  for (usize byte = 0; byte < length; ++byte) {
    const usize offset = address + byte;
    *(sdram + offset) = get_ch();
  }
  verify_space();
}

void stk_read_page(u16 address) {
  set_hex(0x0bbb);
  u8 length = get_length();
  get_ch();
  verify_space();
  volatile usize *sdram = (usize *)&__prog_start;
  for (usize byte = 0; byte < length; ++byte) {
    const usize offset = address + byte;
    put_ch(*(sdram + offset));
  }
}

void stk_load_address(u16 *const address) {
  // set_hex(0xccc);
  u16 lo, hi;
  lo = get_ch();
  hi = get_ch() << 8;
  *address = lo | hi;
  // set_hex(*address);
}

void init_prog_mem() {
  volatile usize *sdram = (usize *)&__prog_start, line = 1;
  while (sdram < &__prog_end) {
    *sdram = line;
    ++sdram;
    ++line;
  }
}

int main() {

  init_prog_mem();

  u8 ch = 1;

  // Skip all logic and run bootloader if MCUSR is cleared (application request)
  if (ch != 0) {
    /*
     * To run the boot loader, External Reset Flag must be set.
     * If not, we could make shortcut and jump directly to application code.
     * Also WDRF set with EXTRF is a result of Optiboot timeout, so we
     * shouldn't run bootloader in loop :-) That's why:
     *  1. application is running if WDRF is cleared
     *  2. we clear WDRF if it's set with EXTRF to avoid loops
     * One problematic scenario: broken application code sets watchdog timer
     * without clearing MCUSR before and triggers it quickly. But it's
     * recoverable by power-on with pushed reset button.
     */
  }

  /*Flash onboard LED to signal entering of bootloader */
  set_7segm(0b00000101001111010011001100000000);
  sleep(200);

  u16 address;
  set_7segm(0);

  /* Forever loop: exits by causing WDT reset */
  for (;;) {
    /* get character from UART */
    ch = get_ch();
    switch (ch) {
    case STK_GET_PARAMETER:
      __gpio_led = 1 << 0;
      stk_get_parameter();
      break;
    case STK_READ_SIGN:
      __gpio_led = 1 << 1;
      // READ SIGN - return what Avrdude wants to hear
      verify_space();
      put_ch(SIGNATURE_0);
      put_ch(SIGNATURE_1);
      put_ch(SIGNATURE_2);
      break;
    case STK_SET_DEVICE:
      __gpio_led = 1 << 2;
      // SET DEVICE is ignored
      get_n_ch(20);
      break;
    case STK_SET_DEVICE_EXT:
      __gpio_led = 1 << 3;
      // SET DEVICE EXT is ignored
      get_n_ch(5);
      break;
    case STK_LOAD_ADDRESS:
      __gpio_led = 1 << 4;
      stk_load_address(&address);
      verify_space();
      break;
    case STK_UNIVERSAL:
      __gpio_led = 1 << 5;
      // UNIVERSAL command is ignored
      get_n_ch(4);
      put_ch(0x00);
      break;
    case STK_READ_PAGE:
      __gpio_led = 1 << 6;
      stk_read_page(address);
      break;
    case STK_PROG_PAGE:
      __gpio_led = 1 << 7;
      stk_prog_page(address);
      break;
    case STK_LEAVE_PROGMODE: /* 'Q' */
      verify_space();
      break;
    default:
      __gpio_led = 0;
      // This covers the response to commands like STK_ENTER_PROGMODE
      verify_space();
    }
    put_ch(STK_OK);
  }
}
