#include <stdint.h>

#define IMG_ENGINE_REG (*(volatile uint32_t*)0x0200000C)
#define UART_DATA      (*(volatile uint32_t*)0x02000008)

void put_char(char c) {
    if (c == '\n') put_char('\r');
    UART_DATA = c;
}

void put_str(const char *s) {
    while (*s) put_char(*s++);
}


void put_hex(uint8_t val) {
    const char *hex_chars = "0123456789ABCDEF";
    put_char(hex_chars[(val >> 4) & 0x0F]);
    put_char(hex_chars[val & 0x0F]);
}

int main() {
    put_str("Image Processing\n");

    IMG_ENGINE_REG = 0x05; 
    put_str("INVERT\n");

    while (1) {
        uint32_t reg_val = IMG_ENGINE_REG;

        if (reg_val & 0x100) {
            uint8_t result_pixel = (uint8_t)(reg_val & 0xFF);
            
            put_str("Result: 0x");
            put_hex(result_pixel);
            put_char('\n');
        }

        for (volatile int i = 0; i < 50000; i++);
    }

    return 0;
}