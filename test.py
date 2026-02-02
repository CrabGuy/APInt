def decimal(digits):
    base = 1 << 52  # Equivalent to 2**52
    return sum(digit * (base**i) for i, digit in enumerate(digits))

baseline = 10 ** 100

x = baseline / (10 ** 15)

BASE = 2 ** 52

a = decimal([3330081849694796, 1000087])
b = decimal([4503599627148868])
multiplier = decimal([18884838484])

print(decimal([221647281636, 3330081849694796])%4503599627148868==2984307530488288)

print("Division: \t", a // b)
print("Modulo: \t", a % b)
print("denormalized\t", 2984307530488288)
print("Modulo devided:\t", (a % b) // multiplier)
print("actual modulo\t", (a // multiplier) % (b // multiplier))


# print(10 ** 100)

# print(x)
# print(from_base_2_52([4503599627370495, 4419942254379007, 1218062511332401, 2252745923636380, 1562451958731451, 5397605]))
