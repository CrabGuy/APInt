def from_base_2_52(digits):
    base = 1 << 52  # Equivalent to 2**52
    return sum(digit * (base**i) for i, digit in enumerate(digits))

baseline = 10 ** 100

x = baseline / (10 ** 15)

BASE = 2 ** 52

print(from_base_2_52([2, 3, 4]) // from_base_2_52([BASE - 1, BASE - 1]))
# print(10 ** 100)

# print(x)
# print(from_base_2_52([4503599627370495, 4419942254379007, 1218062511332401, 2252745923636380, 1562451958731451, 5397605]))
