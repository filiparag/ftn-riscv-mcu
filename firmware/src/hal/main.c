extern void setup(void), loop(void);

int main(void) {
  setup();
  for (;;) {
    loop();
  }
  return 0;
}
