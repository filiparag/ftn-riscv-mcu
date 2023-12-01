
#include "UART.hpp"
#include <stdexcept>
#include <cstdio>

//Used for UART
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>

#include <thread>
#include <chrono>

UART::UART(const string& dev_fn, int baud_rate) {

	//OPEN THE UART
	//The flags (defined in fcntl.h):
	//	Access modes (use 1 of these):
	//		O_RDONLY - Open for reading only.
	//		O_RDWR - Open for reading and writing.
	//		O_WRONLY - Open for writing only.
	//
	//	O_NDELAY / O_NONBLOCK (same function) - Enables nonblocking mode. When set read requests on the file can return immediately with a failure status
	//											if there is no input immediately available (instead of blocking). Likewise, write requests can also return
	//											immediately with a failure status if the output can't be written immediately.
	//
	//	O_NOCTTY - When set and path identifies a terminal device, open() shall not cause the terminal device to become the controlling terminal for the process.
	uart_fd = open(dev_fn.c_str(), O_RDWR | O_NOCTTY | O_NDELAY);		//Open in non blocking read/write mode
	if (uart_fd == -1){
		throw runtime_error("Error - Unable to open UART! Ensure it is not in use by another application.");
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
			throw runtime_error("Unexisting baud rate!");
			break;
	}
	
	//CONFIGURE THE UART
	//The flags (defined in /usr/include/termios.h - see http://pubs.opengroup.org/onlinepubs/007908799/xsh/termios.h.html):
	//	Baud rate:- B1200, B2400, B4800, B9600, B19200, B38400, B57600, B115200, B230400, B460800, B500000, B576000, B921600, B1000000, B1152000, B1500000, B2000000, B2500000, B3000000, B3500000, B4000000
	//	CSIZE:- CS5, CS6, CS7, CS8
	//	CLOCAL - Ignore modem status lines
	//	CREAD - Enable receiver
	//	IGNPAR = Ignore characters with parity errors
	//	ICRNL - Map CR to NL on input (Use for ASCII comms where you want to auto correct end of line characters - don't use for bianry comms!)
	//	PARENB - Parity enable
	//	PARODD - Odd parity (else even)
	struct termios options;
	tcgetattr(uart_fd, &options);
	options.c_cflag = baud_rate_code | CS8 | CLOCAL | CREAD;		//<Set baud rate
	options.c_iflag = IGNPAR;
	options.c_oflag = 0;
	options.c_lflag = 0;
	tcflush(uart_fd, TCIFLUSH);
	tcsetattr(uart_fd, TCSANOW, &options);
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

void UART::write(const void* buf, size_t count) {
	const uint8_t* it = reinterpret_cast<const uint8_t*>(buf);
	while(true){
		ssize_t r = ::write(uart_fd, it, count);
		
		if(r < 0){
			if(errno == EAGAIN){
				// Buffer full. Try again later.
				POLL_SLEEP();
			}else{
				throw runtime_error("UART TX error");
			}
		}else if(r < count){
			count -= r;
			it += r;
		}else{
			break;
		}
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
				throw runtime_error("UART RX error");
			}
		}else if(r < count){
			count -= r;
			it += r;
		}else{
			break;
		}
	}
}

vector<uint8_t> UART::read() {
	vector<uint8_t> d(256);
	ssize_t r = ::read(uart_fd, (void*)d.data(), 256);
	
	if(r < 0){
		//An error occured (will occur if there are no bytes).
		//TODO Handle it.
	}else if (r == 0){
		//No data waiting.
		d.resize(r);
	}else{
		//Bytes received
		d.resize(r);
	}
	
	return d;
}
