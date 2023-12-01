
#include "uart.hpp"

#include <cstdio>
#include <cerrno>

//Used for UART
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>


extern "C" {
	#include "vpi_user.h"
}



UART::UART(const char* dev_fn, int baud_rate) {
	// Open in non blocking read/write mode.
	// The flags (defined in fcntl.h):
	//	O_RDWR
	//		read/write mode.
	//	O_NONBLOCK
	//		Enables nonblocking mode.
	//		Instead of blocking,
	//		read can return immediately
	//		with a failure status
	//		if there is no input immediately available.
	//		Likewise, write requests can also return immediately
	//		with a failure status
	//		if the output cannot be written immediately.
	//	O_NOCTTY
	//		When set and path identifies a terminal device,
	//		open() shall not cause the terminal device
	//		to become the controlling terminal for the process.
	uart_fd = open(dev_fn, O_RDWR | O_NONBLOCK | O_NOCTTY);
	if (uart_fd == -1){
		fprintf(stderr, 
			"ERROR: Unable to open UART!"\
				"Ensure it is not in use by another application.\n"
		);
		return;
	}
	
	int baud_rate_code;
	switch(baud_rate){
		case 1200:
			baud_rate_code = B1200;
			break;
		case 2400:
			baud_rate_code = B2400;
			break;
		case 4800:
			baud_rate_code = B4800;
			break;
		case 9600:
			baud_rate_code = B9600;
			break;
		case 19200:
			baud_rate_code = B19200;
			break;
		case 38400:
			baud_rate_code = B38400;
			break;
		case 57600:
			baud_rate_code = B57600;
			break;
		case 115200:
			baud_rate_code = B115200;
			break;
		case 230400:
			baud_rate_code = B230400;
			break;
		case 460800:
			baud_rate_code = B460800;
			break;
		case 500000:
			baud_rate_code = B500000;
			break;
		case 576000:
			baud_rate_code = B576000;
			break;
		case 921600:
			baud_rate_code = B921600;
			break;
		case 1000000:
			baud_rate_code = B1000000;
			break;
		case 1152000:
			baud_rate_code = B1152000;
			break;
		case 1500000:
			baud_rate_code = B1500000;
			break;
		case 2000000:
			baud_rate_code = B2000000;
			break;
		case 2500000:
			baud_rate_code = B2500000;
			break;
		case 3000000:
			baud_rate_code = B3000000;
			break;
		case 3500000:
			baud_rate_code = B3500000;
			break;
		case 4000000:
			baud_rate_code = B4000000;
			break;
		default:
			//TODO vpi_printf
			fprintf(stderr, "ERROR: Unexisting baud rate!\n");
			return;
			break;
	}
	
	//CONFIGURE THE UART
	//The flags (defined in /usr/include/termios.h - see http://pubs.opengroup.org/onlinepubs/007908799/xsh/termios.h.html):
	//	Baud rate:- B1200, B2400, B4800, B9600, B19200, B38400, B57600, B115200, B230400, B460800, B500000, B576000, B921600, B1000000, B1152000, B1500000, B2000000, B2500000, B3000000, B3500000, B4000000
	//	CSIZE:- CS5, CS6, CS7, CS8
	//	CLOCAL - Ignore modem status lines
	//	CREAD - Enable receiver
	//	IGNPAR - Ignore characters with parity errors
	//	ICRNL - Map CR to NL on input (Use for ASCII comms where you want to auto correct end of line characters - don't use for bianry comms!)
	//	PARENB - Parity enable
	//	PARODD - Odd parity (else even)
	struct termios options;
	tcgetattr(uart_fd, &options);
	options.c_cflag = baud_rate_code | CS8 | CLOCAL | CREAD;
	options.c_iflag = IGNPAR;
	options.c_oflag = 0;
	options.c_lflag = 0;
	tcflush(uart_fd, TCIFLUSH);
	tcsetattr(uart_fd, TCSANOW, &options);

	vpi_printf((char*)"VPI: %s done!\n", __PRETTY_FUNCTION__);
}

UART::~UART() {
	close(uart_fd);
}

#if 0
#define POLL_SLEEP() \
	do{ \
		std::this_thread::sleep_for(std::chrono::microseconds(1)); \
	}while(0)
#else
#define POLL_SLEEP()
#endif

void UART::write(uint8_t c) {
	int written = ::write(uart_fd, &c, 1);

	if(written != 1){
		fprintf(
			stderr,
			"UART TX error: %d of 1B written with errno = %d\n",
			written,
			errno
		);
	}
}

/**
 * @return true if successful.
 */
bool UART::try_read(uint8_t& c) {
	int rx_length = ::read(uart_fd, reinterpret_cast<void*>(&c), 1);

	if(rx_length == 1){
		return true;
	}else{
		// -1 An error occured aka no more bytes.
		// 0 Nothing read.
//TODO Nicer.
/*
vpi_printf((char*)"VPI: %s uart_fd = %d\n", __PRETTY_FUNCTION__, uart_fd);
vpi_printf((char*)"VPI: %s rx_length = %d\n", __PRETTY_FUNCTION__, rx_length);
vpi_printf((char*)"VPI: %s errno = %d\n", __PRETTY_FUNCTION__, errno);
vpi_printf((char*)"VPI: %s EAGAIN = %d\n", __PRETTY_FUNCTION__, EAGAIN);
*/
		return false; // Non-blocking.
	}
}

void UART::read(void* buf, size_t count) {
	uint8_t* it = reinterpret_cast<uint8_t*>(buf);
	while(true){
		ssize_t r = ::read(uart_fd, (void*)&*it, count);
		
		if(r < 0){
			if(errno == EAGAIN){
				// Buffer empty. Try again later.
				POLL_SLEEP();
			}else{
//				throw runtime_error("UART RX error");
				exit(-1);
			}
		}else if(r < count){
			count -= r;
			it += r;
		}else{
			break;
		}
	}
}
