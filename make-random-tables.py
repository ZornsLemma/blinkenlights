import sys

# Multiplier taken from "Computationally easy, spectrally good multipliers for
# congruential pseudorandom number generators" by Guy Steele and Sebastiano
# Vigna (https://arxiv.org/abs/2001.05304).
a = 0xadb4a92d

with open(sys.argv[1], "w") as f:
    f.write("; AUTO-GENERATED, DO NOT EDIT! Edit %s instead.\n\n" % sys.argv[0])

    for n in range(0, 4):
        f.write(".mult_by_a_table%d\n" % n)
        for i in range(0, 256):
            f.write("    equb &%02x\n" % (((a * i) >> (n * 8)) & 0xff))
