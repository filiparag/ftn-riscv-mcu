
extern "C" {
	#include "vpi_user.h"
}

#include "uart.hpp"

#define DEV "/dev/ttyUSB1"
#define BAUDRATE 2000000

static UART* uart = nullptr;
//static UART* uart = new UART(DEV, BAUDRATE);


static int send_tx(char *userdata) {
//	vpi_printf((char*)"VPI: Entered send_tx\n");
	// Obtain a handle to the argument list.
	vpiHandle systfref = vpi_handle(vpiSysTfCall, nullptr);
	vpiHandle args_iter = vpi_iterate(vpiArgument, systfref);

	vpiHandle argh;
	struct t_vpi_value argval;
	// Grab the value of the first argument.
	argh = vpi_scan(args_iter);
	argval.format = vpiIntVal;
	vpi_get_value(argh, &argval);
	int tx_data = argval.value.integer;
//	vpi_printf((char*)"VPI: send_tx = 0x%02x\n", tx_data);

	// Send data to UART.
	uart->write((char)tx_data);

	// Cleanup and return.
	vpi_free_object(args_iter);
	return 0;
}

static int peek_rx(char *userdata) {
//	vpi_printf((char*)"VPI: Entered peek_rx\n");
	// Obtain a handle to the argument list.
	vpiHandle systfref = vpi_handle(vpiSysTfCall, nullptr);
	vpiHandle args_iter = vpi_iterate(vpiArgument, systfref);
//vpi_printf((char*)"VPI: peex_rx\n");

#if 1
	// Get something from UART.
	uint8_t rx_data;
	bool rx_valid = uart->try_read(rx_data);
//vpi_printf((char*)"VPI: peex_rx rx_valid = %d\n", rx_valid);
	if(rx_valid) {
//		vpi_printf((char*)"VPI: rx_valid!");
	}
/*
	bool rx_valid;

	rx_data = uart->read<uint8_t>();		//TODO FIXME should be something better
	if(rx_data) {
		rx_valid = true;
	}
	*/
#else
	uint8_t rx_data = 10;
	bool rx_valid = true;
#endif
	vpiHandle argh;
	struct t_vpi_value argval;
	
	// 1st argument.
	argh = vpi_scan(args_iter);
	argval.format = vpiIntVal;
	argval.value.integer = rx_valid;
	vpi_put_value(argh, &argval, nullptr, vpiNoDelay);
	
	// 2nd argument.
	argh = vpi_scan(args_iter);
	argval.format = vpiIntVal;
	argval.value.integer = rx_data;
	vpi_put_value(argh, &argval, nullptr, vpiNoDelay);

	if(rx_data != 0) {
//		vpi_printf((char*)"VPI: peek_rx_data = 0x%02x\n", rx_data);
	}

	// Cleanup and return
	vpi_free_object(args_iter);
	return 0;
}

// Registers the increment system task
void startup() {
	uart = new UART(DEV, BAUDRATE);
	
	s_vpi_systf_data data;
	data = {vpiSysTask, 0, (char*)"$send_tx", send_tx, 0, 0, 0};
	vpi_register_systf(&data);
	data = {vpiSysTask, 0, (char*)"$peek_rx", peek_rx, 0, 0, 0};
	vpi_register_systf(&data);
}

// Contains a zero-terminated list of functions
// that have to be called at startup.
extern "C" {
	void (*vlog_startup_routines[])() = {
		startup,
		0
	};
}
