#include <hal/gpio.h>
#include <hal/irq.h>
#include <hal/time.h>

#define WORD_SIZE 4
#define MAX_THREADS 4
#define STACK_SIZE 64
#define NO_THREAD -1
#define TIME_SLICE 1000

struct Thread {
  bool used;
  usize stack[STACK_SIZE];
  union StackFrame frame;
};

enum Scheduling { PREEMPTIVE, COOPERATIVE, HYBRID };

struct Mutex {
  volatile bool wants_to_enter[MAX_THREADS];
  volatile usize turn;
};

static volatile struct Thread runtime_threads[MAX_THREADS];
static volatile enum Scheduling runtime_scheduling;
static volatile isize runtime_current_thread_id = NO_THREAD;

void yield(void) {
  extern void __ecall(void);
  if (runtime_scheduling != PREEMPTIVE) {
    __ecall();
  }
}

void critical_section_enter(void) { irq_set_enabled(IRQ_NONE); }

void critical_section_leave(void) {
  if (runtime_scheduling != COOPERATIVE) {
    irq_set_enabled(IRQ_ECALL | IRQ_TIMER0);
  } else {
    irq_set_enabled(IRQ_ECALL);
  }
}

isize threads_new_id(void) {
  for (usize t = 0; t < MAX_THREADS; ++t) {
    if (!runtime_threads[t].used) {
      return t;
    }
  }
  return NO_THREAD;
}

isize threads_next_id(void) {
  for (usize t = 1; t <= MAX_THREADS; ++t) {
    const usize thread_id = (runtime_current_thread_id + t) % MAX_THREADS;
    if (runtime_threads[thread_id].used) {
      return thread_id;
    }
  }
  return NO_THREAD;
}

void thread_guard(const usize thread_id,
                  const void (*const entrypoint)(const void *const),
                  const void *const argument) {
  entrypoint(argument);
  runtime_threads[thread_id].used = false;
  extern void __ecall(void);
  __ecall();
}

isize thread_create(void (*const entrypoint)(const void *const),
                    const void *const argument) {
  critical_section_enter();
  const isize thread_id = threads_new_id();
  if (thread_id == NO_THREAD) {
    critical_section_leave();
    return NO_THREAD;
  }
  struct Thread *const thread = (struct Thread *)&runtime_threads[thread_id];
  thread->used = true;
  critical_section_leave();
  thread->frame.abi.pc = (ptr)thread_guard;
  thread->frame.abi.a0 = thread_id;
  thread->frame.abi.a1 = (ptr)entrypoint;
  thread->frame.abi.a2 = (ptr)argument;
  thread->frame.abi.sp =
      (ptr)(&thread->stack) + (sizeof(usize) * (STACK_SIZE - 1));
  return thread_id;
}

void thread_frame_copy(union StackFrame *const dst,
                       const union StackFrame *const src) {
  struct StackFrameRegs *const d = (struct StackFrameRegs *)dst;
  const struct StackFrameRegs *const s = (struct StackFrameRegs *)src;
  d->pc = s->pc;
  d->x1 = s->x1;
  d->x2 = s->x2;
  d->x3 = s->x3;
  d->x4 = s->x4;
  d->x5 = s->x5;
  d->x6 = s->x6;
  d->x7 = s->x7;
  d->x8 = s->x8;
  d->x9 = s->x9;
  d->x10 = s->x10;
  d->x11 = s->x11;
  d->x12 = s->x12;
  d->x13 = s->x13;
  d->x14 = s->x14;
  d->x15 = s->x15;
  d->x16 = s->x16;
  d->x17 = s->x17;
  d->x18 = s->x18;
  d->x19 = s->x19;
  d->x20 = s->x20;
  d->x21 = s->x21;
  d->x22 = s->x22;
  d->x23 = s->x23;
  d->x24 = s->x24;
  d->x25 = s->x25;
  d->x26 = s->x26;
  d->x27 = s->x27;
  d->x28 = s->x28;
  d->x29 = s->x29;
  d->x30 = s->x30;
  d->x31 = s->x31;
}

void context_switch(const usize irqs, union StackFrame *const frame) {
  const isize next_thread_id = threads_next_id();
  if (runtime_current_thread_id == NO_THREAD) {
    if (next_thread_id == NO_THREAD) {
      return;
    }
    union StackFrame *const new_frame =
        (union StackFrame *)&runtime_threads[next_thread_id].frame;
    thread_frame_copy(frame, new_frame);
    runtime_current_thread_id = next_thread_id;
    return;
  }
  if (next_thread_id == runtime_current_thread_id) {
    return;
  }
  union StackFrame *const current_frame =
      (union StackFrame *)&runtime_threads[runtime_current_thread_id].frame;
  union StackFrame *const next_frame =
      (union StackFrame *)&runtime_threads[next_thread_id].frame;
  thread_frame_copy(current_frame, frame);
  thread_frame_copy(frame, next_frame);
  runtime_current_thread_id = next_thread_id;
}

void runtime_initialize(const enum Scheduling scheduling) {
  runtime_scheduling = scheduling;
  for (usize t = 0; t < MAX_THREADS; ++t) {
    runtime_threads[t].used = false;
  }
  irq_set_handler(IRQ_ECALL, context_switch);
  if (runtime_scheduling != COOPERATIVE) {
    irq_set_handler(IRQ_TIMER0, context_switch);
    irq_set_enabled(IRQ_ECALL | IRQ_TIMER0);
    timer_set_interval(TIMER0, TIME_SLICE);
  } else {
    irq_set_enabled(IRQ_ECALL);
  }
}

void runtime_start(void) {
  if (runtime_scheduling != COOPERATIVE) {
    timer_set_enabled(TIMER0, true);
  }
  yield();
}

void mutex_init(struct Mutex *const mutex) {
  for (usize t = 0; t < MAX_THREADS; ++t) {
    mutex->wants_to_enter[t] = false;
  }
  mutex->turn = 0;
}

void mutex_lock(struct Mutex *const mutex, const usize thread_id) {
  mutex->wants_to_enter[thread_id] = true;
  for (usize p = 0; p < MAX_THREADS; p++) {
    if (p != thread_id) {
      while (mutex->wants_to_enter[p]) {
        if (mutex->turn == p) {
          mutex->wants_to_enter[thread_id] = false;
          while (mutex->turn == p)
            yield();
          mutex->wants_to_enter[thread_id] = true;
        }
      }
    }
  }
}

void mutex_unlock(struct Mutex *const mutex, const usize thread_id) {
  mutex->turn = thread_id;
  mutex->wants_to_enter[thread_id] = false;
}

void print(const char *const buffer, const usize length) {
  static volatile bool mutex_initialized = false;
  static volatile struct Mutex mutex;
  if (!mutex_initialized) {
    critical_section_enter();
    if (!mutex_initialized) {
      mutex_init((struct Mutex *)&mutex);
      mutex_initialized = true;
    }
    critical_section_leave();
  }
  mutex_lock((struct Mutex *)&mutex, runtime_current_thread_id);
  put_buff(UART1, buffer, length);
  mutex_unlock((struct Mutex *)&mutex, runtime_current_thread_id);
}

void await(const u64 ms) {
  const u64 start = millis();
  while (millis() - start < ms) {
    yield();
  }
}

u32 rand(const u32 range_start, const u32 range_end) {
  const u32 A = 1664525;
  const u32 C = 1013904223;
  const u32 M = 2147483648;
  static u32 seed;
  if (range_start > range_end) {
    return 0;
  }
  seed = (A * seed + C) % M;
  return range_start + (seed % (range_end - range_start + 1));
}

u32 factorial(const u32 n) {
  if (n <= 1) {
    return 1;
  }
  return n * factorial(n - 1);
}

void worker1(const void *const arg) {
  print("\033[1;32mFactorial worker started\033[0m\n", 36);
  for (;;) {
    for (u32 n = 1; n <= 8; ++n) {
      set_hex(factorial(n));
      await(1000);
    }
  }
}

void worker2(const void *const arg) {
  print("\033[1;32mLED array worker started\033[0m\n", 36);
  extern volatile u16 __gpio_led_sem;
  for (u8 n = 1; n != 0; ++n) {
    __gpio_led_sem = n;
    sleep(10);
  }
  print("\033[1;31mLED array worker completed\033[0m\n", 38);
}

const char *const OUTPUT_TEXT_1 =
    "\033[0;33mPraesent pulvinar maximus mauris sed porta. "
    "In tincidunt felis ut justo viverra.\033[0m\n";

const char *const OUTPUT_TEXT_2 =
    "\033[0;34mFusce tincidunt egestas libero id molestie. "
    "In porttitor, elit eu congue ligula.\033[0m\n";

void worker3(const void *const arg) {
  print("\033[1;32mRace condition worker started\033[0m\n", 41);
  if (arg == NULLPTR) {
    print("\033[1;31mRace condition worker terminated\033[0m\n\n", 44);
    return;
  }
  for (;;) {
    print(arg, 93);
    await(rand(10, 1000));
  }
}

void setup(void) {
  runtime_initialize(HYBRID);
  thread_create(worker1, NULLPTR);
  thread_create(worker2, NULLPTR);
  thread_create(worker3, OUTPUT_TEXT_1);
  thread_create(worker3, OUTPUT_TEXT_2);
  runtime_start();
}

void loop(void) {}
