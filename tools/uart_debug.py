import argparse
import time

import serial
from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("serial_dev")
    args = parser.parse_args()

    image = Image.open("/home/jwilcox/Pictures/test_image2.png")

    with serial.Serial(args.serial_dev, 230400, timeout=1) as uart:
        write_framebuffer(uart, image)
        # read_framebuffer(uart)


def write_framebuffer(uart, image):
    uart.write(cmd_reg_write("A", 4))
    uart.write((0).to_bytes())
    uart.write((0).to_bytes())
    uart.write((0).to_bytes())
    uart.write((0).to_bytes())

    for y in range(240):
        for x in range(320):
            color = image.getpixel((x, y))
            color_hi = (((color[0] >> 3) & 0b11111) << 3) | ((color[1] >> 5) & 0b111)
            color_lo = (((color[1] >> 3) & 0b111) << 5) | ((color[2] >> 3) & 0b11111)
            uart.write(cmd_reg_write("D", 2))
            uart.write((color_hi).to_bytes())
            uart.write((color_lo).to_bytes())

            uart.write(cmd_execute("W", sel=0b1111, inc=True))
            time.sleep(0.0005)


def read_framebuffer(uart):
    uart.write(cmd_reg_write("A", 4))
    uart.write((0).to_bytes())
    uart.write((0).to_bytes())
    uart.write((0).to_bytes())
    uart.write((0).to_bytes())
    uart.write(cmd_reg_write("D", 4))
    uart.write((0x55).to_bytes())
    uart.write((0x55).to_bytes())
    uart.write((0x55).to_bytes())
    uart.write((0x55).to_bytes())

    for i in range(320 * 240):
        uart.write(cmd_execute("R", sel=0b1111, inc=True))
        uart.write(cmd_reg_read("D", 2))
        result = uart.read(2)
        print(result)


OP_REG_READ = 0b01
OP_REG_WRITE = 0b10
OP_EXECUTE = 0b11


# 7:6    (unused)
# 5:3    Length
#   2    D=0, A=1
# 1:0    Opcode
def cmd_reg_write(reg, len):
    reg_bin = 1 if reg == "A" else 0
    return (OP_REG_WRITE | reg_bin << 2 | len << 3).to_bytes()


# 7:6    (unused)
# 5:3    Length
#   2    D=0, A=1
# 1:0    Opcode
def cmd_reg_read(reg, len):
    reg_bin = 1 if reg == "A" else 0
    return (OP_REG_READ | reg_bin << 2 | len << 3).to_bytes()


# 7:4    Byte select
#   3    Auto-increment A reg
#   2    Read=0, Write=1
# 1:0    Opcode
def cmd_execute(op, inc, sel):
    op_bin = 1 if op == "W" else 0
    inc_bin = 1 if inc else 0
    return (OP_EXECUTE | op_bin << 2 | inc_bin << 3 | sel << 4).to_bytes()


if __name__ == "__main__":
    main()
