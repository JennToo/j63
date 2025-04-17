import argparse

import serial


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("serial_dev")
    args = parser.parse_args()

    with serial.Serial(args.serial_dev, 230400) as uart:
        uart.write(cmd_reg_write("A", 4))
        uart.write((0).to_bytes())
        uart.write((0).to_bytes())
        uart.write((0).to_bytes())
        uart.write((0).to_bytes())
        uart.write(cmd_reg_write("D", 2))
        uart.write((0).to_bytes())
        uart.write((0xFF).to_bytes())

        for i in range(320 * 240):
            uart.write(cmd_execute("W", inc=True))


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
