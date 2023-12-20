#include "../include/gpio.h"
#include "../include/irq.h"
#include "../include/stk500.h"
#include "../include/time.h"
#include "../include/uart.h"

#define CPU_FREQUENCY 50e6

#define LED_START_FLASHES 2

#define OPTIBOOT_MAJVER 8
#define OPTIBOOT_MINVER 3
#define OPTIBOOT_CUSTOMVER 11

#define SIGNATURE_0 0x1E
#define SIGNATURE_1 0x95
#define SIGNATURE_2 0x0F

unsigned const int optiboot_version =
    256 * (OPTIBOOT_MAJVER + OPTIBOOT_CUSTOMVER) + OPTIBOOT_MINVER;

extern const usize *__prog_start;
extern const usize *__prog_end;
extern void __reset(void);

typedef uint8_t pagelen_t;

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

void flash_led(const usize n) {
  for (usize i = 0; i < n; ++i) {
    __gpio_led = 1 << 7;
    sleep(50);
    __gpio_led = 0;
    sleep(50);
  }
  __gpio_led = 0;
}

uint8_t chcnt;
char getch(void) {
  char c;
  __gpio_led = 1;
  get_ch(&c);
  __gpio_led = 0;
  ++chcnt;
  return c;
}

void putch(const char ch) {
  __gpio_led = 2;
  put_ch(ch);
  __gpio_led = 0;
}

void verifySpace() {
  if (getch() != CRC_EOP) {
    // watchdogConfig(WATCHDOG_16MS); // shorten WD timeout
    // while (1) // and busy-loop so that WD causes
    // ;       //  a reset and app start.
    sleep(16);
    // __reset();
  }
  putch(STK_INSYNC);
}

void getNch(const usize count) {
  volatile char _;
  for (usize i = 0; i < count; ++i) {
    _ = getch();
  }
  verifySpace();
}

void read_mem(uint8_t memtype, addr16_t address, pagelen_t length) {
  uint8_t ch;

  uint8_t *sdram = (uint8_t *)&__prog_start;

  switch (memtype) {

  default:
    do {

      // read a Flash byte and increment the address
      // __asm__("  lpm %0,Z+\n" : "=r"(ch), "=z"(address.bptr) : "1"(address));

      ch = *(sdram + address.word);
      ++address.bptr;

      putch(ch);
    } while (--length);
    break;
  } // switch
}

void writebuffer(int8_t memtype, addr16_t mybuff, addr16_t address,
                 pagelen_t len) {
  switch (memtype) {
  case 'E': // EEPROM
    /*
     * On systems where EEPROM write is not supported, just busy-loop
     * until the WDT expires, which will eventually cause an error on
     * host system (which is what it should do.)
     */
    while (1)
      ; // Error: wait for WDT
    break;
  default: // FLASH
    /*
     * Default to writing to Flash program memory.  By making this
     * the default rather than checking for the correct code, we save
     * space on chips that don't support any other memory types.
     */
    {
      // Copy buffer into programming buffer
      uint16_t addrPtr = address.word;

      /*
       * Start the page erase and wait for it to finish.  There
       * used to be code to do this while receiving the data over
       * the serial link, but the performance improvement was slight,
       * and we needed the space back.
       */

      // __boot_page_erase_short(address.word);
      // boot_spm_busy_wait();
      // sleep(5);

      uint8_t *sdram = (uint8_t *)&__prog_start;
      usize offset = 0;
      while (offset < 1000 /*__prog_end - __prog_start*/) {
        *(sdram + offset) = 0;
      }

      /*
       * Copy data from the buffer into the flash write buffer.
       */
      do {
        // __boot_page_fill_short((uint16_t)(void *)addrPtr, *(mybuff.wptr++));

        // addrPtr += 2;
      } while (len -= 2);

      /*
       * Actually Write the buffer to flash (and wait for it to finish.)
       */
      // __boot_page_write_short(address.word);
      // boot_spm_busy_wait();
      // sleep(5);

    } // default block
    break;
  } // switch
}

static addr16_t buff;

#define GETLENGTH(len)                                                         \
  len = getch() << 8;                                                          \
  len |= getch()

void stk_get_parameter() {
  unsigned char which = getch();
  verifySpace();
  /*
   * Send optiboot version as "SW version"
   * Note that the references to memory are optimized away.
   */
  if (which == STK_SW_MINOR) {
    putch(optiboot_version & 0xFF);
  } else if (which == STK_SW_MAJOR) {
    putch(optiboot_version >> 8);
  } else {
    /*
     * GET PARAMETER returns a generic 0x03 reply for
     * other parameters - enough to keep Avrdude happy
     */
    putch(0x03);
  }
}

void stk_prog_page(pagelen_t *length, addr16_t *address) {
  uint8_t desttype;
  uint8_t *bufPtr;
  pagelen_t savelength;

  GETLENGTH(*length);
  savelength = *length;
  desttype = getch();

  // read a page worth of contents
  bufPtr = buff.bptr;
  do
    *bufPtr++ = getch();
  while (--length);

  // Read command terminator, start reply
  verifySpace();

  writebuffer(desttype, buff, *address, savelength);
}

void stk_read_page(pagelen_t *length, addr16_t *address) {
  uint8_t desttype;
  GETLENGTH(*length);

  desttype = getch();

  verifySpace();

  read_mem(desttype, *address, *length);
}

int main() {
  chcnt = 0;

  register uint8_t ch = 1;

  /*
   * Making these local and in registers prevents the need for initializing
   * them, and also saves space because code no longer stores to memory.
   * (initializing address keeps the compiler happy, but isn't really
   *  necessary, and uses 4 bytes of flash.)
   */
  addr16_t address;
  pagelen_t length;

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
  flash_led(LED_START_FLASHES);

  // while (!__gpio_btn_sw)
  //   ;

  set_7segm(0b00000101001111010011001100000000);

  /* Forever loop: exits by causing WDT reset */
  for (;;) {
    __gpio_led = 0;
    /* get character from UART */
    ch = getch();
    switch (ch) {
    case STK_GET_PARAMETER:
      set_hex(ch); // debug
      stk_get_parameter();
      set_hex(ch << 8); // debug
      break;
    case STK_READ_SIGN:
      set_hex(ch); // debug
      // READ SIGN - return what Avrdude wants to hear
      __gpio_led = 0xff;
      verifySpace();
      putch(SIGNATURE_0);
      putch(SIGNATURE_1);
      putch(SIGNATURE_2);
      set_hex(ch << 8); // debug
      break;
    case STK_SET_DEVICE:
      set_hex(ch); // debug
      getNch(20);
      set_hex(ch << 8); // debug
      break;
    case STK_SET_DEVICE_EXT:
      set_hex(ch); // debug
      getNch(5);
      set_hex(ch << 8); // debug
      break;
    case STK_LOAD_ADDRESS:
      set_hex(ch); // debug
      address.bytes[0] = getch();
      address.bytes[1] = getch();
      address.word *= 2; // Convert from word address to byte address
      verifySpace();
      set_hex(ch << 8); // debug
      break;
    case STK_UNIVERSAL:
      set_hex(ch); // debug
      getNch(4);
      putch(0x00);
      set_hex(ch << 8); // debug
      break;
    case STK_PROG_PAGE:
      set_hex(ch); // debug
      stk_prog_page(&length, &address);
      set_hex(ch << 8); // debug
      break;
    case STK_READ_PAGE:
      set_hex(ch); // debug
      stk_read_page(&length, &address);
      set_hex(ch << 8); // debug
      break;
    case STK_LEAVE_PROGMODE: /* 'Q' */
      set_hex(ch);           // debug
      verifySpace();
      set_hex(ch << 8); // debug
      break;
    default:
      __gpio_led = 1 << 6;
      verifySpace();
      __gpio_led = 0;
    }
    putch(STK_OK);
  }
}
