BASE = 2**52

def decimal(digits):
    return sum(digit * (BASE**i) for i, digit in enumerate(digits))

a = decimal([1, 2, 3])
b = decimal([2251799813685249])
multiplier = 1


print("q = ", decimal([4503599627370488, 5]))
print("r = ", decimal([11, 1]))

print("Division: \t", a // b)
print("Modulo: \t", a % b)
print("Modulo devided:\t", (a % b) // multiplier)
print("actual modulo\t", (a // multiplier) % (b // multiplier))
