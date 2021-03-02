import random

count = 40*32
centre_frequency = 2
frequency_half_range = 0.3

random.seed(42)

frequencies = [random.uniform(centre_frequency - frequency_half_range, centre_frequency + frequency_half_range) for x in range(count)]
frames = [int(50/x) for x in frequencies]
print(frames)
print(min(frames), max(frames))

initial_state = [False] * count
state = initial_state[:]
current_frame = 0
something_toggled = False
while True:
    current_frame += 1
    for i, frame in enumerate(frames):
        if current_frame % frame == 0:
            state[i] = not state[i]
            something_toggled = True
            print current_frame, i
    #if state == [not x for x in initial_state]:
    if state == initial_state and something_toggled:
        break
