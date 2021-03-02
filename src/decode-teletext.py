import base64
import sys

# Note that this does not perform the character switches the Acorn OS does, so
# for accurate reproduction the resulting data should be poked directly into
# screen RAM instead of written via OSWRCH.
def decode_edittf_url(url):
    i = url.index("#")
    s = url[i+1:]
    i = s.index(":")
    s = s[i+1:]
    s += "===="
    packed_data = bytearray(base64.urlsafe_b64decode(s))
    unpacked_data = bytearray()
    buffer = 0
    buffer_bits = 0
    while len(packed_data) > 0 or buffer_bits > 0:
        if buffer_bits < 7:
            if len(packed_data) > 0:
                packed_byte = packed_data.pop(0)
            else:
                packed_byte = 0
            buffer = (buffer << 8) | packed_byte
            buffer_bits += 8
        byte = buffer >> (buffer_bits - 7)
        if byte < 32:
            byte += 128
        unpacked_data.append(byte)
        buffer &= ~(0b1111111 << (buffer_bits - 7))
        buffer_bits -= 7
    # ENHANCEMENT: At the moment if the edit.tf page contains double-height text
    # the user must make sure to duplicate it on both lines. We could
    # potentially adjust this automatically.
    return unpacked_data

args = sys.argv[:]
led = args[1] == "--led"
if led:
    args[1:] = args[2:]

with open(args[1], "r") as f:
    encoded = f.readline()

decoded = decode_edittf_url(encoded)
if not led:
    with open(args[2], "wb") as f:
        f.write(decoded)
else:
    with open(args[2], "w") as f:
        f.write("; AUTO-GENERATED, DO NOT EDIT! Edit %s instead.\n\n" % sys.argv[0])
        for y in range(5):
            for x in range(2):
                f.write("    ; Shape %d, %s\n" % (y, "large" if x == 0 else "small"))
                for yo in range(3):
                    for xo in range(4):
                        cx = 2 + x*5 + xo
                        cy = 1 + y*4 + yo
                        i = cy*40 + cx
                        f.write("    equb &%02x\n" % decoded[i])
                for i in range(4):
                    f.write("    equb &00 ; padding\n")
