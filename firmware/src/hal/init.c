#include <hal/init.h>

extern void __reset(void) __attribute__((noreturn)) __attribute__((naked));
extern void __exit(void) __attribute__((noreturn)) __attribute__((naked));

void reset(void) { __reset(); }

void exit(const int code) { __exit(); }
