import sys

a = 0xadb4a92d

with open(sys.argv[1], "w") as f:
    f.write("; AUTO-GENERATED, DO NOT EDIT! Edit %s instead.\n\n" % sys.argv[0])

    for n in range(0, 4):
        f.write(".table%d\n" % n)
        for i in range(0, 256):
            f.write("    equb &%02x\n" % (((a * i) >> (n * 8)) & 0xff))
