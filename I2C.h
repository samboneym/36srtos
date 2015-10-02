/*
 * I2C.h
 *
 *  Created on: 23/09/2015
 *      Author: samant
 */

#ifndef I2C_H_
#define I2C_H_

#define I2C_ACK 1
#define I2C_NACK 0

void i2cInitialise();

void i2cAcquire(unsigned char address);

void i2cRelease();

void i2cSend(unsigned char data);

unsigned char i2cReceive();

#endif /* I2C_H_ */
