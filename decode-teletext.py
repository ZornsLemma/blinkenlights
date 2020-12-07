import base64
import sys

# SFTODO: Do I need to do the three character switches the OS performs automatically? We will be outputting the mode 7 header/footer using PRINT not direct memory access.
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
    # SFTODO: At the moment if the edit.tf page contains double-height text the
    # user must make sure to duplicate it on both lines. We could potentially adjust
    # this automatically.
    return unpacked_data

with open(sys.argv[1], "r") as f:
    encoded = f.readline()

with open(sys.argv[2], "wb") as f:
    f.write(decode_edittf_url(encoded))
