import random

count = 40*32
centre_frequency = 2
frequency_half_range = 0.3

random.seed(42)

frequencies = [random.uniform(centre_frequency - frequency_half_range, centre_frequency + frequency_half_range) for x in range(count)]
frames = [int(50/x) for x in frequencies]
print(frames)
print(min(frames), max(frames))
