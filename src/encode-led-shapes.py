import itertools
import sys

def mybin(i):
    return "%" + ("00000000"+ (bin(i)[2:]))[-8:]

# This will not always generate "optimal" output - it may be possible to
# shorten (but not speed up) the code generated by compile_led_shape from this
# output by re-ordering the scanline numbers for a group to allow more use of
# iny/dey instead of ldy #n. Unless space gets so tight that the space-saving
# matter, it isn't worth complicating the code to improve this.
def encode_shape(f, name, shape):
    global labels
    assert ("large" in name and len(shape) == 6) or ("small" in name and len(shape) == 4)
    shape_sorted = sorted(enumerate(shape), key=lambda x: x[1])
    shape_sorted = [(x, y) for (x, y) in shape_sorted if y != 0]
    label = "led_shape_%s" % name
    f.write(".%s\n" % label)
    labels.append(label)
    for k, g in itertools.groupby(shape_sorted, key=lambda x: x[1]):
        f.write("   equb %s, %s\n" % (mybin(k), ", ".join([str(x[0]) for x in g] + ["128"])))
    f.write("   equb 0\n")

labels = []

with open(sys.argv[1], "w") as f:
    f.write("; AUTO-GENERATED, DO NOT EDIT! Edit %s instead.\n\n" % sys.argv[0])

    encode_shape(f, "0_large", (0b00111100,
                                0b01111110,
                                0b01111110,
                                0b01111110,
                                0b01111110,
                                0b00111100))
    encode_shape(f, "0_small", (0b00011000,
                                0b00111100,
                                0b00111100,
                                0b00011000))

    encode_shape(f, "1_large", (0b00010000,
                                0b00111000,
                                0b01111100,
                                0b00111000,
                                0b00010000,
                                0b00000000))
    encode_shape(f, "1_small", (0b00010000,
                                0b00111000,
                                0b00010000,
                                0b00000000))

    encode_shape(f, "2_large", (0b00000000,
                                0b01111110,
                                0b01111110,
                                0b01111110,
                                0b00000000,
                                0b00000000))
    encode_shape(f, "2_small", (0b00000000,
                                0b00111100,
                                0b00111100,
                                0b00000000))

    encode_shape(f, "3_large", (0b01111110,
                                0b01111110,
                                0b01111110,
                                0b01111110,
                                0b01111110,
                                0b01111110))
    encode_shape(f, "3_small", (0b00111100,
                                0b00111100,
                                0b00111100,
                                0b00111100))

    encode_shape(f, "4_large", (0b00010000,
                                0b00010000,
                                0b00111000,
                                0b00111000,
                                0b01111100,
                                0b01111100))
    encode_shape(f, "4_small", (0b00010000,
                                0b00111000,
                                0b01111100,
                                0b00000000))

    f.write("\nnum_led_shapes = %d\n" % (len(labels)/2))
    f.write(".led_shape_list\n")
    for i in range(0, len(labels), 2):
        f.write("    equw %s, %s\n" % (labels[i], labels[i+1]))
