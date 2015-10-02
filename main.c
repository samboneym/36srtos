#include <avr/io.h>
#include <stdio.h>

#include <FreeRTOS.h>
#include <task.h>

#include "uart.h"
#include "I2C.h"

#define DS3232_I2C_ADDRESS (0x68)

static portTASK_FUNCTION(readTemp, args) {
	while (1) {
		i2cAcquire(DS3232_I2C_ADDRESS);
		i2cSend(0x11);
		unsigned char tempMSB = i2cReceive(I2C_ACK);
		unsigned char tempLSB = i2cReceive(I2C_NACK) >> 6;
		i2cRelease();

		printf("Temp %d.%d C\n", tempMSB, 25 * tempLSB);

		vTaskDelay(1000 / portTICK_PERIOD_MS);
	}
}

int main(void) {
	// UART
	uart_init();
	stdout = &uart_output;
	stdin = &uart_input;

	// I2C
	i2cInitialise();

	xTaskCreate(readTemp, "readTemp", configMINIMAL_STACK_SIZE * 2, NULL, tskIDLE_PRIORITY + 1, NULL);
	vTaskStartScheduler();
	return 0;
}
