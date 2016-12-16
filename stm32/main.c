/*
 * This program turns on the 4 leds of the stm32f4 discovery board
 * one after another.
 * It defines shortcut definitions for the led pins and
 * stores the order of the leds in an array which is being
 * iterated in a loop.
 *
 * This program is free human culture like poetry, mathematics
 * and science. You may use it as such.
 */

#include <math.h>
#include <stdlib.h>
#include <string.h>

#include <stm32f4xx.h>


#define PERIPH_REG_ADR_LOW 0x00
#define PERIPH_REG_ADR_HIGH 0x02
#define PERIPH_REG_DATA 0x04

#define MCU_HZ 168000000

/* This is apparently needed for libc/libm (eg. powf()). */
int __errno;


static void delay(uint32_t nCount)
{
  /* This should be 3 cycles per iteration. nCount must be > 0. */
  __asm volatile
    ("\n"
     "0:\n\t"
     "subs %1, #1\n\t"
     "bne.n 0b"
     : "=r" (nCount)
     : "0" (nCount)
     : "cc");
}


static void setup_serial(void)
{
  GPIO_InitTypeDef GPIO_InitStructure;
  USART_InitTypeDef USART_InitStructure;

  /* enable peripheral clock for USART1 */
  RCC_APB2PeriphClockCmd(RCC_APB2Periph_USART1, ENABLE);

  /* GPIOB clock enable */
  RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOB, ENABLE);

  /* GPIOB Configuration:  USART1 TX on PB6 */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_6;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
  GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;
  GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP ;
  GPIO_Init(GPIOB, &GPIO_InitStructure);

  /* Connect USART1 pins to AF2 */
  // TX = PB6
  GPIO_PinAFConfig(GPIOB, GPIO_PinSource6, GPIO_AF_USART1);

  USART_InitStructure.USART_BaudRate = 115200;
  USART_InitStructure.USART_WordLength = USART_WordLength_8b;
  USART_InitStructure.USART_StopBits = USART_StopBits_1;
  USART_InitStructure.USART_Parity = USART_Parity_No;
  USART_InitStructure.USART_HardwareFlowControl = USART_HardwareFlowControl_None;
  USART_InitStructure.USART_Mode = USART_Mode_Tx;
  USART_Init(USART1, &USART_InitStructure);

  USART_Cmd(USART1, ENABLE); // enable USART1
}


#define LED1_GPIO_PERIPH RCC_AHB1Periph_GPIOC
#define LED1_GPIO GPIOC
#define LED1_PIN GPIO_Pin_7
#define LED2_GPIO_PERIPH RCC_AHB1Periph_GPIOA
#define LED2_GPIO GPIOA
#define LED2_PIN GPIO_Pin_8

static void
setup_leds(void)
{
  GPIO_InitTypeDef GPIO_InitStructure;

  RCC_AHB1PeriphClockCmd(LED1_GPIO_PERIPH, ENABLE);
  GPIO_InitStructure.GPIO_Pin = LED1_PIN;
  GPIO_InitStructure.GPIO_Mode  = GPIO_Mode_OUT;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;
  GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;
  GPIO_InitStructure.GPIO_PuPd  = GPIO_PuPd_NOPULL;
  GPIO_Init(LED1_GPIO, &GPIO_InitStructure);

  RCC_AHB1PeriphClockCmd(LED2_GPIO_PERIPH, ENABLE);
  GPIO_InitStructure.GPIO_Pin = LED2_PIN;
  GPIO_InitStructure.GPIO_Mode  = GPIO_Mode_OUT;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;
  GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;
  GPIO_InitStructure.GPIO_PuPd  = GPIO_PuPd_NOPULL;
  GPIO_Init(LED2_GPIO, &GPIO_InitStructure);
}


__attribute__((unused))
static void
led1_on(void)
{
  GPIO_SetBits(LED1_GPIO, LED1_PIN);
}


__attribute__((unused))
static void
led1_off(void)
{
  GPIO_ResetBits(LED1_GPIO, LED1_PIN);
}


__attribute__((unused))
static void
led2_on(void)
{
  GPIO_SetBits(LED2_GPIO, LED2_PIN);
}


__attribute__((unused))
static void
led2_off(void)
{
  GPIO_ResetBits(LED2_GPIO, LED2_PIN);
}


static void
serial_putchar(USART_TypeDef* USARTx, uint32_t c)
{
  while(!(USARTx->SR & USART_FLAG_TC));
  USART_SendData(USARTx, c);
}


static void
serial_puts(USART_TypeDef *usart, const char *s)
{
  while (*s)
    serial_putchar(usart, (uint8_t)*s++);
}


static void
serial_output_hexdig(USART_TypeDef* USARTx, uint32_t dig)
{
  serial_putchar(USARTx, (dig >= 10 ? 'A' - 10 + dig : '0' + dig));
}


__attribute__ ((unused))
static void
serial_output_hexbyte(USART_TypeDef* USARTx, uint8_t byte)
{
  serial_output_hexdig(USARTx, byte >> 4);
  serial_output_hexdig(USARTx, byte & 0xf);
}


__attribute__ ((unused))
static void
serial_output_hex(USART_TypeDef* USARTx, uint32_t v)
{
  serial_putchar(USARTx, '0');
  serial_putchar(USARTx, 'x');
  serial_output_hexbyte(USARTx, v >> 24);
  serial_output_hexbyte(USARTx, (v >> 16) & 0xff);
  serial_output_hexbyte(USARTx, (v >> 8) & 0xff);
  serial_output_hexbyte(USARTx, v & 0xff);
}


__attribute__ ((unused))
static char *
tostring_uint32(char *p, uint32_t val)
{
  uint32_t l, d;

  l = 1000000000UL;
  while (l > val && l > 1)
    l /= 10;

  do
  {
    d = val / l;
    *p++ = '0' + d;
    val -= d*l;
    l /= 10;
  } while (l > 0);
  return p;
}


__attribute__ ((unused))
static void
print_uint32(USART_TypeDef* usart, uint32_t val)
{
  char buf[13];
  char *p;

  p = tostring_uint32(buf, val);
  *p = '\0';
  serial_puts(usart, buf);
}


__attribute__ ((unused))
static void
println_uint32(USART_TypeDef* usart, uint32_t val)
{
  char buf[13];
  char *p = buf;

  p = tostring_uint32(buf, val);
  *p++ = '\r';
  *p++ = '\n';
  *p = '\0';
  serial_puts(usart, buf);
}


__attribute__ ((unused))
static void
println_int32(USART_TypeDef* usart, int32_t val)
{
  if (val < 0)
  {
    serial_putchar(usart, '-');
    println_uint32(usart, (uint32_t)0 - (uint32_t)val);
  }
  else
    println_uint32(usart, val);
}


static void
float_to_str(char *buf, float f, uint32_t dig_before, uint32_t dig_after)
{
  float a;
  uint32_t d;
  uint8_t leading_zero;

  if (f == 0.0f)
  {
    buf[0] = '0';
    buf[1] = '\0';
    return;
  }
  if (f < 0)
  {
    *buf++ = '-';
    f = -f;
  }
  a =  powf(10.0f, (float)dig_before);
  if (f >= a)
  {
    buf[0] = '#';
    buf[1] = '\0';
    return;
  }
  leading_zero = 1;
  while (dig_before)
  {
    a /= 10.0f;
    d = (uint32_t)(f / a);
    if (leading_zero && d == 0 && a >= 10.0f)
      *buf++ = ' ';
    else
    {
      leading_zero = 0;
      *buf++ = '0' + d;
      f -= d*a;
    }
    --dig_before;
  }
  if (!dig_after)
  {
    *buf++ = '\0';
    return;
  }
  *buf++ = '.';
  do
  {
    f *= 10.0f;
    d = (uint32_t)f;
    *buf++ = '0' + d;
    f -= (float)d;
    --dig_after;
  } while (dig_after);
  *buf++ = '\0';
}


__attribute__ ((unused))
static void
println_float(USART_TypeDef* usart, float f,
              uint32_t dig_before, uint32_t dig_after)
{
  char buf[21];
  char *p = buf;

  float_to_str(p, f, dig_before, dig_after);
  while (*p)
    ++p;
  *p++ = '\r';
  *p++ = '\n';
  *p = '\0';
  serial_puts(usart, buf);
}


__attribute__((unused))
static void
write_fpga(uint32_t offset, uint16_t val)
{
  /* 0x64000000 is the start of bank1 SRAM2. */
  volatile uint16_t *fpga = (volatile uint16_t *)(uint32_t)0x64000000;

  *(fpga+(offset>>1)) = val;
}


__attribute__((unused))
static uint16_t
read_fpga(uint32_t offset)
{
  /* 0x64000000 is the start of bank1 SRAM2. */
  volatile uint16_t *fpga = (volatile uint16_t *)(uint32_t)0x64000000;

  return *(fpga+(offset>>1));
}


__attribute__((unused))
static void
write_sdram(uint32_t addr, uint16_t val)
{
  uint16_t addr_high = (addr >> 16);
  uint16_t addr_low = (addr & 0xfffe);
  write_fpga(PERIPH_REG_DATA, val);
  write_fpga(PERIPH_REG_ADR_HIGH, addr_high);
  write_fpga(PERIPH_REG_ADR_LOW, addr_low | 1);
  // Wait until operation done.
  while (read_fpga(PERIPH_REG_ADR_LOW) & 1)
    ;
}


__attribute__((unused))
static uint16_t
read_sdram(uint32_t addr)
{
  uint16_t addr_high = (addr >> 16);
  uint16_t addr_low = (addr & 0xfffe);
  write_fpga(PERIPH_REG_ADR_HIGH, addr_high);
  write_fpga(PERIPH_REG_ADR_LOW, addr_low | 0);
  // Wait until operation done.
  while (read_fpga(PERIPH_REG_ADR_LOW) & 1)
    ;
  return read_fpga(PERIPH_REG_DATA);
}


__attribute__((unused))
static void
ice40_sdram_test1(void)
{
  uint16_t val;
  uint32_t ledstate;
  uint16_t counter;
  uint16_t v1, v2, v3, v4;
  uint16_t status1, status2, status3, status4;

  ledstate = 0;
  counter = 0;
  for(;;) {
    val = read_fpga(PERIPH_REG_ADR_LOW);
    serial_puts(USART1, "Read adr_low: ");
    serial_output_hex(USART1, val);
    serial_puts(USART1, "\r\n");
    val = read_fpga(PERIPH_REG_ADR_HIGH);
    serial_puts(USART1, "Read adr_high: ");
    serial_output_hex(USART1, val);
    serial_puts(USART1, "\r\n");
    val = read_fpga(PERIPH_REG_DATA);
    serial_puts(USART1, "Read data: ");
    serial_output_hex(USART1, val);
    serial_puts(USART1, "\r\n");

    write_fpga(PERIPH_REG_ADR_HIGH, (uint16_t)0x0800 + counter);
    val = read_fpga(PERIPH_REG_ADR_HIGH);
    serial_puts(USART1, "Read after write adr_high: ");
    serial_output_hex(USART1, val);
    serial_puts(USART1, "\r\n");
    write_fpga(PERIPH_REG_DATA, counter);
    val = read_fpga(PERIPH_REG_DATA);
    serial_puts(USART1, "Read after write data: ");
    serial_output_hex(USART1, val);
    serial_puts(USART1, "\r\n");

    // Execute a write-to-SDRAM.
    status1 = read_fpga(0x10);
    serial_puts(USART1, "Status pre: ");
    serial_output_hex(USART1, status1);
    serial_puts(USART1, "\r\n");

    write_fpga(PERIPH_REG_ADR_HIGH, 0x0006);
    write_fpga(PERIPH_REG_DATA, 0xfd00 | (counter & 0xffff));
    write_fpga(PERIPH_REG_ADR_LOW, 0x0101);
    v1 = read_fpga(PERIPH_REG_ADR_LOW);
    v2 = read_fpga(PERIPH_REG_ADR_LOW);
    v3 = read_fpga(PERIPH_REG_ADR_LOW);
    v4 = read_fpga(PERIPH_REG_ADR_LOW);
    serial_puts(USART1, "Attempt to do write: ");
    serial_output_hex(USART1, v1);
    serial_puts(USART1, " ");
    serial_output_hex(USART1, v2);
    serial_puts(USART1, " ");
    serial_output_hex(USART1, v3);
    serial_puts(USART1, " ");
    serial_output_hex(USART1, v4);
    serial_puts(USART1, "\r\n");
    // Execute a write-to-SDRAM.
    status2 = read_fpga(0x10);
    serial_puts(USART1, "Status post-write: ");
    serial_output_hex(USART1, status2);
    serial_puts(USART1, "\r\n");

    // Execute a read-from-SDRAM.
    write_fpga(PERIPH_REG_DATA, 0xabad);
    status3 = read_fpga(0x10);
    serial_puts(USART1, "Status pre-read: ");
    serial_output_hex(USART1, status3);
    serial_puts(USART1, "\r\n");
    write_fpga(PERIPH_REG_ADR_LOW, 0x0100);
    v1 = read_fpga(PERIPH_REG_ADR_LOW);
    v2 = read_fpga(PERIPH_REG_ADR_LOW);
    v3 = read_fpga(PERIPH_REG_ADR_LOW);
    val = read_fpga(PERIPH_REG_DATA);
    v4 = read_fpga(PERIPH_REG_ADR_LOW);
    serial_puts(USART1, "Attempt to do read: ");
    serial_output_hex(USART1, v1);
    serial_puts(USART1, " ");
    serial_output_hex(USART1, v2);
    serial_puts(USART1, " ");
    serial_output_hex(USART1, v3);
    serial_puts(USART1, " ");
    serial_output_hex(USART1, val);
    serial_puts(USART1, " ");
    serial_output_hex(USART1, v4);
    serial_puts(USART1, "\r\n");
    status4 = read_fpga(0x10);
    serial_puts(USART1, "Status post-read: ");
    serial_output_hex(USART1, status4);
    serial_puts(USART1, "\r\n");

    ++counter;
    if ((ledstate = !ledstate))
      led1_on();
    else
      led1_off();
    delay(MCU_HZ/3);
  }
}


__attribute__((unused))
static void
ice40_sdram_test2(void)
{
  uint32_t ledstate;
  uint16_t counter;
  uint16_t v1, v2, v3, v4, v5;

  ledstate = 0;
  counter = 0;
  for(;;) {
    write_sdram(0x1238, (counter+3)&0xffff);
    write_sdram(0x1232, counter&0xffff);
    write_sdram(0x1236, (counter+2)&0xffff);
    write_sdram(0x1234, (counter+1)&0xffff);
    v1 = read_sdram(0x1232);
    //delay(MCU_HZ/3/1000000*100);
    v2 = read_sdram(0x1234);
    v3 = read_sdram(0x1236);
    v4 = read_sdram(0x1238);
    v5 = read_sdram(0x1232);
    serial_puts(USART1, "Readback after write ");
    serial_output_hex(USART1, (counter&0xffff));
    serial_puts(USART1, ": ");
    serial_output_hex(USART1, v1);
    serial_puts(USART1, " ");
    serial_output_hex(USART1, v2);
    serial_puts(USART1, ": ");
    serial_output_hex(USART1, v3);
    serial_puts(USART1, " ");
    serial_output_hex(USART1, v4);
    serial_puts(USART1, " ");
    serial_output_hex(USART1, v5);
    serial_puts(USART1, "\r\n");

    ++counter;
    if ((ledstate = !ledstate))
      led1_on();
    else
      led1_off();
    if (counter & 2)
      led2_on();
    else
      led2_off();
    delay(MCU_HZ/3);
  }
}


__attribute__((unused))
static void
ice40_sdram_test3(void)
{
  uint32_t ledstate;
  uint16_t counter;
  uint16_t v1, v2, v3, v4, v5;

  ledstate = 0;
  counter = 0;
  for(;;) {
    write_fpga(PERIPH_REG_ADR_HIGH, 0x2222);
    v1 = read_fpga(PERIPH_REG_ADR_HIGH);
    write_fpga(PERIPH_REG_ADR_HIGH, 0x4444);
    v2 = read_fpga(PERIPH_REG_ADR_HIGH);
    write_fpga(PERIPH_REG_ADR_HIGH, 0x6666);
    v3 = read_fpga(PERIPH_REG_ADR_HIGH);
    write_fpga(PERIPH_REG_ADR_HIGH, 0x8888);
    v4 = read_fpga(PERIPH_REG_ADR_HIGH);
    write_fpga(PERIPH_REG_ADR_HIGH, 0xaaaa);
    v5 = read_fpga(PERIPH_REG_ADR_HIGH);

    serial_puts(USART1, "FSMC interface readback: ");
    serial_output_hex(USART1, v1);
    serial_puts(USART1, " ");
    serial_output_hex(USART1, v2);
    serial_puts(USART1, " ");
    serial_output_hex(USART1, v3);
    serial_puts(USART1, ": ");
    serial_output_hex(USART1, v4);
    serial_puts(USART1, " ");
    serial_output_hex(USART1, v5);
    serial_puts(USART1, "\r\n");

    ++counter;
    if ((ledstate = !ledstate))
      led1_on();
    else
      led1_off();
    if (counter & 2)
      led2_on();
    else
      led2_off();
    delay(MCU_HZ/3);
  }
}


__attribute__((unused))
static void
ice40_sdram_test4(void)
{
  uint32_t i, j;
  static const uint32_t fixadr = 0x00080000;

  for(;;) {
    for (i = 0; i < 32; ++i) {
      write_sdram(((i<<3)+fixadr)<<1, (i)&0xffff);
      if (i & 1)
        led1_off();
      else
        led1_on();
    }
    for (i = 0; i < 32; i += 8) {
      serial_output_hex(USART1, (((i+0)<<3)+fixadr) << 1);
      serial_puts(USART1, ":");
      for (j = 0; j < 8; ++j) {
        uint16_t v = read_sdram( (((i+j)<<3)+fixadr) << 1 );
        serial_puts(USART1, " ");
        serial_output_hex(USART1, v);
        if (j & 1)
          led2_off();
        else
          led2_on();
      }
      serial_puts(USART1, "\r\n");
    }
    serial_puts(USART1, "\r\n");

    delay(MCU_HZ/3);
  }
}


static void
fsmc_manual_init(void)
{
  FSMC_NORSRAMInitTypeDef fsmc_init;
  FSMC_NORSRAMTimingInitTypeDef timing, alttiming;
  GPIO_InitTypeDef GPIO_InitStructure;

  /* GPIOD, E, F, and G clock enable */
  RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOD, ENABLE);
  RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOE, ENABLE);
  RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOF, ENABLE);
  RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOG, ENABLE);

  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_0|GPIO_Pin_1|GPIO_Pin_4|GPIO_Pin_5|
    GPIO_Pin_7|GPIO_Pin_8|GPIO_Pin_9|GPIO_Pin_10|GPIO_Pin_11|
    GPIO_Pin_12|GPIO_Pin_13|GPIO_Pin_14|GPIO_Pin_15;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;
  GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;
  GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_NOPULL;
  GPIO_Init(GPIOD, &GPIO_InitStructure);
  GPIO_PinAFConfig(GPIOD, GPIO_PinSource0, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOD, GPIO_PinSource1, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOD, GPIO_PinSource4, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOD, GPIO_PinSource5, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOD, GPIO_PinSource7, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOD, GPIO_PinSource8, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOD, GPIO_PinSource9, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOD, GPIO_PinSource10, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOD, GPIO_PinSource11, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOD, GPIO_PinSource12, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOD, GPIO_PinSource13, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOD, GPIO_PinSource14, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOD, GPIO_PinSource15, GPIO_AF_FSMC);

  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_0|GPIO_Pin_1|GPIO_Pin_3|GPIO_Pin_4|
    GPIO_Pin_7|GPIO_Pin_8|GPIO_Pin_9|GPIO_Pin_10|GPIO_Pin_11|
    GPIO_Pin_12|GPIO_Pin_13|GPIO_Pin_14|GPIO_Pin_15;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;
  GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;
  GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_NOPULL;
  GPIO_Init(GPIOE, &GPIO_InitStructure);
  GPIO_PinAFConfig(GPIOE, GPIO_PinSource0, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOE, GPIO_PinSource1, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOE, GPIO_PinSource3, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOE, GPIO_PinSource4, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOE, GPIO_PinSource7, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOE, GPIO_PinSource8, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOE, GPIO_PinSource9, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOE, GPIO_PinSource10, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOE, GPIO_PinSource11, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOE, GPIO_PinSource12, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOE, GPIO_PinSource13, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOE, GPIO_PinSource14, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOE, GPIO_PinSource15, GPIO_AF_FSMC);

  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_0|GPIO_Pin_1|GPIO_Pin_2|GPIO_Pin_3|
    GPIO_Pin_4|GPIO_Pin_5|GPIO_Pin_12|GPIO_Pin_13|GPIO_Pin_14|GPIO_Pin_15;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;
  GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;
  GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_NOPULL;
  GPIO_Init(GPIOF, &GPIO_InitStructure);
  GPIO_PinAFConfig(GPIOF, GPIO_PinSource0, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOF, GPIO_PinSource1, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOF, GPIO_PinSource2, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOF, GPIO_PinSource3, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOF, GPIO_PinSource4, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOF, GPIO_PinSource5, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOF, GPIO_PinSource12, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOF, GPIO_PinSource13, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOF, GPIO_PinSource14, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOF, GPIO_PinSource15, GPIO_AF_FSMC);

  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_0|GPIO_Pin_1|GPIO_Pin_2|GPIO_Pin_3|
    GPIO_Pin_4|GPIO_Pin_5|GPIO_Pin_9;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;
  GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;
  GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_NOPULL;
  GPIO_Init(GPIOG, &GPIO_InitStructure);
  GPIO_PinAFConfig(GPIOG, GPIO_PinSource0, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOG, GPIO_PinSource1, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOG, GPIO_PinSource2, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOG, GPIO_PinSource3, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOG, GPIO_PinSource4, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOG, GPIO_PinSource5, GPIO_AF_FSMC);
  GPIO_PinAFConfig(GPIOG, GPIO_PinSource9, GPIO_AF_FSMC);

  RCC_AHB3PeriphClockCmd(RCC_AHB3Periph_FSMC, ENABLE);
  FSMC_NORSRAMDeInit(FSMC_Bank1_NORSRAM1);
  FSMC_NORSRAMCmd(FSMC_Bank1_NORSRAM1, DISABLE);
  FSMC_NORSRAMDeInit(FSMC_Bank1_NORSRAM2);

  fsmc_init.FSMC_Bank = FSMC_Bank1_NORSRAM1;
  fsmc_init.FSMC_DataAddressMux = FSMC_DataAddressMux_Disable;
  fsmc_init.FSMC_MemoryType = FSMC_MemoryType_SRAM;
  fsmc_init.FSMC_MemoryDataWidth = FSMC_MemoryDataWidth_16b;
  fsmc_init.FSMC_BurstAccessMode = FSMC_BurstAccessMode_Disable;
  fsmc_init.FSMC_AsynchronousWait = FSMC_AsynchronousWait_Disable;
  fsmc_init.FSMC_WaitSignalPolarity = FSMC_WaitSignalPolarity_Low;
  fsmc_init.FSMC_WrapMode = FSMC_WrapMode_Disable;
  fsmc_init.FSMC_WaitSignalActive = FSMC_WaitSignalActive_BeforeWaitState;
  fsmc_init.FSMC_WriteOperation = FSMC_WriteOperation_Enable;
  fsmc_init.FSMC_WaitSignal = FSMC_WaitSignal_Disable;
  fsmc_init.FSMC_ExtendedMode = FSMC_ExtendedMode_Enable;
  fsmc_init.FSMC_WriteBurst = FSMC_WriteBurst_Disable;
  fsmc_init.FSMC_ReadWriteTimingStruct = &timing;
  fsmc_init.FSMC_WriteTimingStruct = &alttiming;

  /* Read timing. */
  timing.FSMC_AddressSetupTime = 2;
  timing.FSMC_AddressHoldTime = 0xf;
  timing.FSMC_DataSetupTime = 10;
  timing.FSMC_BusTurnAroundDuration = 2;
  timing.FSMC_CLKDivision = 0xf;
  timing.FSMC_DataLatency = 0xf;
  timing.FSMC_AccessMode = FSMC_AccessMode_A;

  /* Write timing. */
  alttiming.FSMC_AddressSetupTime = 2;
  alttiming.FSMC_AddressHoldTime = 0xf;
  alttiming.FSMC_DataSetupTime = 8;
  alttiming.FSMC_BusTurnAroundDuration = 2;
  alttiming.FSMC_CLKDivision = 0xf;
  alttiming.FSMC_DataLatency = 0xf;
  alttiming.FSMC_AccessMode = FSMC_AccessMode_A;

  FSMC_NORSRAMInit(&fsmc_init);
  fsmc_init.FSMC_Bank = FSMC_Bank1_NORSRAM2;
  FSMC_NORSRAMInit(&fsmc_init);

  FSMC_NORSRAMCmd(FSMC_Bank1_NORSRAM1, ENABLE);
  FSMC_NORSRAMCmd(FSMC_Bank1_NORSRAM2, ENABLE);
}


int main(void)
{
  delay(2000000);
  setup_serial();
  setup_leds();
  serial_puts(USART1, "Initialising...\r\n");
  delay(2000000);
  fsmc_manual_init();

  serial_puts(USART1, "Hello world, ready to blink!\r\n");

  ice40_sdram_test4();

  return 0;
}
