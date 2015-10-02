#include <FreeRTOS.h>
#include <semphr.h>
#include <task.h>

#include <avr/interrupt.h>
#include <util/twi.h>
#include "i2cmaster.h"

#ifndef F_CPU
#error Missing definition:  F_CPU must be defined
#endif

/* I2C clock in Hz */
#define SCL_CLOCK  100000L

struct I2CBus {
	SemaphoreHandle_t semaphore;
	TaskHandle_t taskToNotify;
	uint8_t address;
	uint8_t status;
	uint8_t data;
	uint8_t busOwner :1;
	uint8_t mode :1;
};

static struct I2CBus bus = { };

ISR(TWI_vect) {
	bus.status = TW_STATUS & 0xF8;
	if (bus.mode == I2C_READ) {
		bus.data = TWDR;
	}

	BaseType_t xHigherPriorityTaskWoken = pdFALSE;
	vTaskNotifyGiveFromISR(bus.taskToNotify, &xHigherPriorityTaskWoken);
	if (xHigherPriorityTaskWoken != pdFALSE) {
		taskYIELD();
	}
}

void i2cInitialise() {
	bus.semaphore = xSemaphoreCreateMutex();
	bus.taskToNotify = NULL;

	TWSR = 0;
	TWBR = ((F_CPU / SCL_CLOCK) - 16) / 2;
}

void i2cAcquire(unsigned char address) {
	xSemaphoreTake(bus.semaphore, portMAX_DELAY);
	bus.address = address << 1;
	bus.taskToNotify = xTaskGetCurrentTaskHandle();
	TWCR |= (1 << TWIE);
}

void i2cRelease() {
	if (bus.busOwner) {
		i2c_stop();
		bus.busOwner = 0;
	}
	TWCR &= ~(1 << TWIE);
	bus.taskToNotify = NULL;
	bus.address = 0;
	xSemaphoreGive(bus.semaphore);
}

void i2cSend(unsigned char data) {
	if (!bus.busOwner) {
		i2c_start_wait(bus.address + I2C_WRITE);
		bus.busOwner = 1;
		bus.mode = I2C_WRITE;
	} else if (bus.mode != I2C_WRITE) {
		i2c_rep_start(bus.address + I2C_WRITE);
		bus.mode = I2C_WRITE;
	}
	i2c_write(data);
}

unsigned char i2cReceive(unsigned char ack) {
	if (!bus.busOwner) {
		i2c_start_wait(bus.address + I2C_READ);
		bus.busOwner = 1;
		bus.mode = I2C_READ;
	} else if (bus.mode != I2C_READ) {
		i2c_rep_start(bus.address + I2C_READ);
		bus.mode = I2C_READ;
	}
	if (ack) {
		return i2c_readAck();
	}
	return i2c_readNak();
}

// ----------------------------------------------------------------------------
// Internal functions
// ----------------------------------------------------------------------------

static void i2cStart(unsigned char address) {
	uint8_t twst;

	while (1) {
		// send START condition
		TWCR = (1 << TWINT) | (1 << TWSTA) | (1 << TWEN);

		// wait until transmission completed
		ulTaskNotifyTake(pdTRUE, portMAX_DELAY);

		// check value of TWI Status Register. Mask prescaler bits.
		twst = TW_STATUS & 0xF8;
		if ((twst != TW_START) && (twst != TW_REP_START))
			continue;

		// send device address
		TWDR = address;
		TWCR = (1 << TWINT) | (1 << TWEN);

		// wail until transmission completed
		while (!(TWCR & (1 << TWINT)))
			;

		// check value of TWI Status Register. Mask prescaler bits.
		twst = TW_STATUS & 0xF8;
		if ((twst == TW_MT_SLA_NACK) || (twst == TW_MR_DATA_NACK)) {
			/* device busy, send stop condition to terminate write operation */
			TWCR = (1 << TWINT) | (1 << TWEN) | (1 << TWSTO);

			// wait until stop condition is executed and bus released
			while (TWCR & (1 << TWSTO))
				;

			continue;
		}
		//if( twst != TW_MT_SLA_ACK) return 1;
		break;
	}

}/* i2c_start_wait */
