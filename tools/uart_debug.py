import argparse

import serial


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("serial_dev")
    args = parser.parse_args()

    with serial.Serial(args.serial_dev, 230400) as uart:
        uart.write(cmd_reg_write("A"))
        uart.write((0).to_bytes())
        uart.write((0).to_bytes())
        uart.write((0).to_bytes())
        uart.write((0).to_bytes())
        uart.write(cmd_reg_write("D"))
        uart.write((0).to_bytes())
        uart.write((0xFF).to_bytes())
        uart.write((0).to_bytes())
        uart.write((0).to_bytes())

        for i in range(320 * 240):
            uart.write(cmd_execute("W", inc=True))


OP_REG_READ = 0b01
OP_REG_WRITE = 0b10
OP_EXECUTE = 0b11


def cmd_reg_write(reg):
    reg_bin = 1 if reg == "A" else 0
    return (OP_REG_WRITE << 6 | reg_bin << 5).to_bytes()


def cmd_reg_read():
    return (OP_REG_READ << 6).to_bytes()


def cmd_execute(op, inc):
    op_bin = 1 if op == "W" else 0
    inc_bin = 1 if inc else 0
    return (OP_REG_WRITE << 6 | op_bin << 5 | inc_bin << 4).to_bytes()


if __name__ == "__main__":
    main()
