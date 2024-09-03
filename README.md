# Softcore Microcontroller with Peripherals Based on PicoRV32

This project implements an FPGA-based RISC-V microcontroller and accompanying firmware, designed primarily for educational purposes. It targets the [Arrow MAX1000](https://www.arrow.com/en/campaigns/max1000) development board, along with a custom peripheral daughterboard.

Jump to the [Examples](#examples) section to explore the capabilities of this platform.

## Hardware architecture

The core of the microcontroller is the [PicoRV32](https://github.com/YosysHQ/picorv32) CPU, which supports the RV32IM instruction set. It interfaces with memory and peripherals via the Wishbone interface, with a system clock set to 50 MHz for all components.

### Address space layout

Communication between the CPU and the components of the microcontroller occurs through a Wishbone bus arbiter. The slave components include a read-only BROM for bootloader, a multi-purpose read-write BRAM, a memory-mapped peripheral controller, and SDRAM. The following table shows the address mapping:

| Component                                           | Purpose            | Size    | Address range          |
| --------------------------------------------------- | ------------------ | ------- | ---------------------- |
| [BRAM](./FPGA/src/memory_bram.vhd)                  | Flashable firmware | 32 KiB  | `0x00000` .. `0x07FFC` |
| [BRAM](./FPGA/src/memory_bram.vhd)                  | Dynamic memory     | 2 KiB   | `0x08000` .. `0x087FC` |
| [BRAM](./FPGA/src/memory_bram.vhd)                  | Stack and heap     | 14 KiB  | `0x08800` .. `0x0BFFC` |
| [Peripheral Controller](./FPGA/src/peripherals.vhd) | GPIO, UART, timers | 16 KiB  | `0x0C000` .. `0x0FFFC` |
| [BROM](./FPGA/src/memory_brom.vhd)                  | Bootloader         | 4 KiB   | `0x10000` .. `0x10FFC` |
| [SDRAM](./FPGA/ip/sdram.v)                          | User-defined       | 956 KiB | `0x11000` .. `0xFFFFC` |

### Peripheral controller

Peripherals consist of both internal and external components. Internal peripherals include `UART0` (via the integrated FT2232H chip), LEDs, and timers, while external peripherals include `UART1` (via an external USB-UART dongle) and other GPIO.

The internal `UART0` is configured to 115200 Bd, while the external `UART1` is set to 2000000 Bd for higher-speed communication.

Timer components include three 64-bit runtime counters (nanosecond, microsecond, millisecond) and four general-purpose 32-bit microsecond looping timers.

The following table contains the memory address offsets of all memory-mapped peripherals (base address is `0xC000`):

| Address offset | Access | Width   | Signal description                       |
| -------------- | ------ | ------- | ---------------------------------------- |
| `0x00`         | rw     | 11 bit  | Internal LEDs and external LED semaphore |
| `0x04`         | ro     | 64 bit  | Runtime nanosecond counter               |
| `0x0C`         | ro     | 64 bit  | Runtime microsecond counter              |
| `0x14`         | ro     | 64 bit  | Runtime millisecond counter              |
| `0x20`         | rw     | 4 bit   | Reset selected timer                     |
| `0x24`         | rw     | 2 bit   | Set selected timer                       |
| `0x28`         | ro     | 32 bit  | Selected timer interval (microseconds)   |
| `0x30`         | ro     | 1 bit   | `UART0` receive ready                    |
| `0x34`         | ro     | 1 bit   | `UART0` transmit ready                   |
| `0x38`         | ro     | 1 bit   | `UART1` receive ready                    |
| `0x3C`         | ro     | 1 bit   | `UART1` transmit ready                   |
| `0x40`         | ro     | 8 bit   | `UART0` receive byte                     |
| `0x44`         | wo     | 8 bit   | `UART0` transmit byte                    |
| `0x48`         | ro     | 8 bit   | `UART1` receive byte                     |
| `0x4C`         | wo     | 8 bit   | `UART1` transmit byte                    |
| `0x50`         | ro     | 13 bit  | External buttons and switches            |
| `0x54`         | rw     | 16 bit  | Hexadecimal 7 segment display output     |
| `0x58`         | rw     | 32 bit  | Custom 7-segment display output          |
| `0x5C`         | rw     | 192 bit | RGB LED matrix display framebuffer       |

#### External interrupts

The PicoRV32 CPU features an interrupt controller with 32 inputs. The first three inputs are reserved for [internal sources](https://github.com/YosysHQ/picorv32?tab=readme-ov-file#custom-instructions-for-irq-handling). The following table lists IRQ inputs connected to the previously mentioned peripherals:

| IRQ  | Interrupt source              |
| ---- | ----------------------------- |
| `4`  | `TIMER0` interval elapsed     |
| `5`  | `TIMER1` interval elapsed     |
| `6`  | `TIMER2` interval elapsed     |
| `7`  | `TIMER3` interval elapsed     |
| `8`  | UART byte received            |
| `9`  | UART byte transmitted         |
| `30` | GPIO button interaction event |
| `31` | GPIO switch interaction event |

## Bootloader

Bootloader is the execution entrypoint upon a microcontroller reset. It is compatible with the [STK500](https://ww1.microchip.com/downloads/en/DeviceDoc/doc1925.pdf) protocol used by [Arduino UNO](https://docs.arduino.cc/hardware/uno-rev3/), allowing it to be flashed using [avrdude](https://github.com/avrdudes/avrdude) programmer.

The bootloader waits for 250 ms after starting, and if no new firmware is being flashed, it jumps to the firmware located in BRAM. It can also be triggered by a `UART1` DTR request, eliminating the need for manual intervention.

> [!NOTE]
> The microcontroller does not store firmware in non-volatile memory, so it is lost on power loss.
> Statically initialized variables are also not restored to their original values on a microcontroller reset.

## Firmware

The firmware comes bundled with [Newlib](https://sourceware.org/newlib/) libc and an extensible hardware abstraction library for peripherals described earlier. Similar to Arduino, the code entrypoint is a `setup()` function, followed by a `loop()` function. Available HAL functionality can be found in the [headers](./firmware/include/hal/) directory.

### Examples

Code examples for the most common use cases are available in [examples](./firmware/) directory:

1. [Blink LED](./firmware/examples/01_blink_led.c)
2. [Seven-segment display hexadecimal output](./firmware/examples/02_seven_segm_hex.c)
3. [Seven-segment display individual segment control](./firmware/examples/03_seven_segm_custom.c)
4. [LED control using buttons and switches](./firmware/examples/04_buttons_and_switches.c)
5. [Graphics rendering on RGB LED matrix](./firmware/examples/05_rgb_led_matrix.c)
6. [Communication over UART](./firmware/examples/06_uart_send_characters.c)
7. [Button state processing using interrupts](./firmware/examples/07_interrupt_handlers.c)
8. [Wall clock using timers](./firmware/examples/08_timers.c)
9. [Concurrent thread execution with context switching](./firmware/examples/09_concurrent_threads.c)

### Development environment

To set up development environment on Linux, download [Quartus Prime](https://www.intel.com/content/www/us/en/products/details/fpga/development-tools/quartus-prime.html) 23.1 (or newer), a native C compiler, [GNU Coreutils](https://www.gnu.org/s/coreutils/), [Python](https://www.python.org/), and [cURL](https://curl.se/). After that, run the following commands in the repository directory:

```shell
cd ./common/tools/
make
cd ../../firmware/lib/
make
```

These commands will prepare the platform develompent tools and libraries.

Next, compile the bootloader and generate the BROM image:

```shell
cd ../../bootloader/
make
```

After this, compile the FPGA design in Quartus Prime and flash it onto the board. The compiled bootloader image will be read during synthesis.

Finally, to build and upload firmware onto the microcontroller, run:

```shell
cd ../firmware/
make
make upload
```

Ensure that the board's `UART0` [serial port path](./firmware/Makefile#L7) matches the one on your system.

Output of `printf()` statements sent to the `UART1` can be accessed via [Arduino CLI](https://www.arduino.cc/pro/software-pro-cli/) Serial Monitor or a similar tool:

```shell
arduino-cli monitor --timestamp --config baudrate=2000000 -p /dev/ttyUSB1
```

To edit the firmware source code, add or modify files in firmware's [source](./firmware/src/) directory.
