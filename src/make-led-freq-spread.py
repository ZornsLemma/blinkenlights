# At runtime we have a primitive urandom8(n) which generates a uniformly
# distributed random number between 0 and n-1 inclusive. For each LED
# (frequency, spread) pair we determine constants a, b, c such that a +
# urandom8(b) + urandom8(c) gives a binominally-distributed range of periods
# with the desired spread. We can then generate uniformly distributed periods as
# a + urandom8(b + c - 1). Ideally we want b=c for a proper binomial
# distribution, but we allow them to be slightly different to get a better
# approximation of the desired range using integer arithmetic.

# We also have a variable number of ticks per 50Hz frame; the higher this value
# the higher the effective resolution of the variable LED periods, but as we
# are working with 8-bit bytes for periods we need to keep that in mind.

import sys

frequencies = (0.5, 1.0, 1.5, 2.0) # Hz
spreads = (0.02, 0.05, 0.1, 0.2) # 1=100%

with open(sys.argv[1], "w") as f:
    f.write("; AUTO-GENERATED, DO NOT EDIT! Edit %s instead.\n\n" % sys.argv[0])

    f.write("num_frequencies = %d\n" % len(frequencies))
    f.write(".frequency_text\n")
    for freq in frequencies:
        f.write('    equs "%3.1f"\n' % freq)

    f.write("\nnum_spreads = %d\n" % len(spreads))
    f.write(".spread_text\n")
    for spread in spreads:
        f.write('    equs "%2d"\n' % (spread * 100))

    f.write("\n.frequency_spread_parameters\n")
    f.write("    ;    tpf, a  , b  , c\n")
    for freq in frequencies:
        for spread in spreads:
                # To be precise, these are half-periods (the time between changes of the
                # LED's state), but we just call them periods.
                min_period = 25.0 / (freq * (1 + spread))
                max_period = 25.0 / (freq * (1 - spread))
                ticks_per_frame = int(255 / max_period)
                min_period = int(round(min_period * ticks_per_frame))
                max_period = int(round(max_period * ticks_per_frame))
                a = min_period
                b_plus_c = max_period - min_period + 2
                b = int(b_plus_c / 2.0)
                c = int(b_plus_c - b)
                # It doesn't make sense to call urandom8(0); urandom8(1) would
                # always return 0, which is valid but a bit pointless.
                assert b > 1
                assert c > 1
                # print (freq, spread, min_period, max_period, ticks_per_frame, a, b, c)
                f.write("    equb %3d, %3d, %3d, %3d ; %3.1fHz +/- %2d%%\n" % (ticks_per_frame, a, b, c, freq, spread * 100))

# TODO: Move all these .py utilities into src or res directory instead of root
# of repository?
