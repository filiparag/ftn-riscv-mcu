
#ifndef UART_HPP
#define UART_HPP

#include <string>
#include <vector>
#include <stdint.h>
using namespace std;

class UART {
public:
	UART(const string& dev_fn, int baud_rate);
	~UART();
	template<typename T>
	void write(const T& t) {
		write(reinterpret_cast<const void*>(&t), sizeof(T));
	}
	template<typename T>
	T read() {
		T t;
		read(reinterpret_cast<void*>(&t), sizeof(T));
		return t;
	}
	/**
	 * Read as much as can.
	 */
	vector<uint8_t> read();
private:
	int uart_fd;
	void write(const void* buf, size_t count);
	void read(void* buf, size_t count);
};

#endif // UART_HPP
