#include <sys/stat.h>

#include <types.h>
#include <uart.h>

extern void __exit(void) __attribute__((noreturn));

enum UART_PORT __fd_to_uart(const int file) {
  switch (file) {
  case 0:
    return UART1;
  case 1:
    return UART1;
  case 2:
    return UART1;
    break;
  default:
    return -1;
  }
}

void *_sbrk(const int incr) {
  extern const usize __sdram_start;
  static u8 *heap = (u8 *)&__sdram_start;
  const u8 *last = heap;
  heap += incr;
  return (void *)last;
}

int _close(const int file) { return -1; }

int _fstat(const int file, struct stat *const st) {
  st->st_mode = S_IFCHR;
  return 0;
}

int _isatty(const int file) { return 1; }

int _lseek(const int file, const int ptr, const int dir) { return 0; }

void _exit(const int status) { __exit(); }

void _kill(const int pid, const int sig) { return; }

int _getpid(void) { return -1; }

int _write(const int file, const char *const ptr, const int len) {
  const enum UART_PORT port = __fd_to_uart(file);
  if (port == -1) {
    return -1;
  }
  for (int i = 0; i < len; ++i) {
    put_ch(port, ptr[i]);
  }
  return len;
}

int _read(const int file, char *const ptr, const int len) {
  const enum UART_PORT port = __fd_to_uart(file);
  if (port == -1) {
    return -1;
  }
  for (int i = 0; i < len; ++i) {
    ptr[i] = get_ch(port);
  }
  return len;
}
