/* UART includes */
#include "UART.hpp"
#include <iostream>
#include <fstream>
#include <chrono>
#include <thread>
/* main.cpp includes */
#include <stdint.h>
#include <math.h>


using namespace std;

#define BAUDRATE 2000000

#define CMD_READ 0x40
#define CMD_WRITE 0x80

#define TEXT_SECTION_START_ADDRESS 0x00000000
#define BUFFER_START_ADDRESS 0x00003004
#define BUFFER_END_ADDRESS 0x00003ffc  
#define BUFFER_SIZE_ADDRESS 0x00003000 
#define RST_REG_ADDRESS 0x11000000


#define dvu32p(a) (*(volatile uint32_t*)(a)) 
#define wait_false(e) while((e) != 0){}
#define wait_true(e) while((e) != 0){}


///////////////////////////////////////////////////////////////////////////////
//	UART functions
///////////////////////////////////////////////////////////////////////////////

struct header_struct {
	uint8_t  cmd;				// 0x40 READ; 0x80 WRITE
	uint32_t data_size : 24; 
	uint32_t address;
} __attribute__((packed));


UART* u;

void uart_write_data(
	header_struct header,
	const uint32_t* data
) {
	u->write(header);

	for(uint32_t i = 0; i < header.data_size / 4; i++ ) {		
		u->write(data[i]);
	}	
};

void uart_read_data(//TODO
	header_struct header,
	uint32_t* data
) {
	u->write(header);
	uint32_t y;
	for(uint32_t i = 0; i < header.data_size / 4; i++) {\
		y = u->read<uint32_t>();
		data[i] = y;
	}
}

void init_fpga_buff() {
	header_struct clear_buff_h = {
		.cmd = CMD_WRITE,
		.data_size = 2048 * 4,
		.address = BUFFER_SIZE_ADDRESS //set size and all elements to 0
	};
	uint32_t init_array[2048];
	for(int i = 0; i < 2048; i++) {
		init_array[i] = 0;
	}
	uart_write_data(clear_buff_h, init_array);
}

void uart_write_buff(const uint32_t* buffer, uint32_t size) {
	header_struct check_buff_h = {
		.cmd = CMD_READ,
		.data_size = 4,				
		.address = BUFFER_SIZE_ADDRESS	
	};
	
	uint32_t buf_status[1] = {5}; // initial temp value
	uint32_t buf_size[1] = {size * 4};
	while(buf_status[0] != 0){ // wait until buffer empty
		uart_read_data(check_buff_h, buf_status);
	}

	header_struct write_buff_h = {
		.cmd = CMD_WRITE,
		.data_size = buf_size[0],
		.address = BUFFER_START_ADDRESS
	};
	
	uart_write_data(write_buff_h, buffer);	

	header_struct buff_written_h = {
		.cmd = CMD_WRITE,
		.data_size = 4,
		.address = BUFFER_SIZE_ADDRESS
	};

	uart_write_data(buff_written_h, buf_size); // write how many bytes were written to buffer size

}

void uart_read_buff(uint32_t* buffer, uint32_t size) {
	header_struct check_buff_h = {
		.cmd = CMD_READ,
		.data_size = 4,
		.address = BUFFER_SIZE_ADDRESS
	};

	uint32_t buf_status[1] = {0};
	uint32_t zero[1] = {0};
	uint32_t buf_size[1] = {size * 4};

	while(buf_status[0] == 0){ //wait until buffer is not empty	
		uart_read_data(check_buff_h, buf_status);
	}

	header_struct read_buff_h = {
		.cmd = CMD_READ,
		.data_size = buf_size[0],
		.address = BUFFER_START_ADDRESS
	};

	uart_read_data(read_buff_h, buffer);

	header_struct buff_red_h = {
		.cmd = CMD_WRITE,
		.data_size = 4,
		.address = BUFFER_SIZE_ADDRESS
	};

	uart_write_data(buff_red_h, zero); // after the data is read, set buffer size to 0
}

///////////////////////////////////////////////////////////////////////////////
// MAIN APP
///////////////////////////////////////////////////////////////////////////////

int main(int argc, char** argv) {
	if(argc < 2){
		cerr << "Wrong number of args!" << endl;
		return 1;
	}
	const char* dev_fn = argv[1];
	
	cerr << "Opening serial port: " << dev_fn << endl;
	u = new UART(
		dev_fn,
		BAUDRATE
	);
	
	const char* hex_fn = argv[2];

	cout << "Reading HEX file" << endl;

	uint32_t hex_array[3072];
	uint32_t read_hex_array[3072];

	
	fstream hex_file;
	hex_file.open(hex_fn);
	if(!hex_file){
		cerr << "Cannot open/find HEX file: " << hex_fn << endl;
		return 1;
	}

	for (int i = 0; i < 3072; i++) {
		hex_file >> hex >> hex_array[i]; 
	}

	uint32_t data_chunk_size = 3072; 		
	// maybe we dont need this to be in a for loop
	cout << "Writing HEX to memory..." << endl;
	//works only in smaller chunks	
	for (int i = 0; i < 3072 / data_chunk_size; i++) {		
		header_struct write_header = {
			.cmd = CMD_WRITE,
			.data_size = data_chunk_size * 4,
			.address = TEXT_SECTION_START_ADDRESS + (i * data_chunk_size * 4)
		};
		uart_write_data(write_header, hex_array);
		std::this_thread::sleep_for(std::chrono::milliseconds(50));		//could be lower
	}
	cout << "Writing successful!" << endl;

	cout << "Reading HEX from memory" << endl;
	header_struct read_header = {
		.cmd = CMD_READ,
		.data_size = 3072 * 4,				
		.address = TEXT_SECTION_START_ADDRESS
	};
	uart_read_data(read_header, read_hex_array);
	cout << "Reading successful!" << endl;

	cout << "Checking if values match..." << endl;
	for(uint32_t i = 0; i < data_chunk_size; i++){
		if(hex_array[i] != read_hex_array[i]){
			cout << "Values do not match at value " << i << " !" << endl;
			cout << "Value written: " << hex_array[i] << " ### Value read: " << read_hex_array[i] << endl;
			return 0;
		}
	}
	cout << "All values match!" << endl;

	cout << "Initializing buffer..." << endl;
	init_fpga_buff();
	cout << "Initializing finished..." << endl;

	std::this_thread::sleep_for(std::chrono::milliseconds(1000));

	cout << "Deasserting reset for proc..." << endl;
	
	uint32_t rst_proc[1] = {0x00000000};

	header_struct rst_proc_msg = {
		.cmd = CMD_WRITE,
		.data_size = 4,				
		.address = RST_REG_ADDRESS			//RST_REG
	};

	uart_write_data(rst_proc_msg, rst_proc);
	
	// Wait for the SDRAM chip to power up
	std::this_thread::sleep_for(std::chrono::milliseconds(500));

	return 0;
}
