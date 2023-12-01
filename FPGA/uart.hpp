
#ifndef UART_HPP
#define UART_HPP

#include <stdint.h>
#include <string>

using namespace std;

class UART {
public:
	UART(const char* dev_fn, int baud_rate);
	~UART();

	void write(uint8_t c);
	bool try_read(uint8_t& c);
	void read(void* buf, size_t count);

	template<typename T>
	T read() {
		T t;
		read(reinterpret_cast<void*>(&t), sizeof(T));
		return t;
	}

private:
	int uart_fd;
};

#endif // UART_HPP
