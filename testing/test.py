BASE = 2**52

def decimal(digits):
    return sum(digit * (BASE**i) for i, digit in enumerate(digits))

a = [2644535368401609, 4794036]
b = [4000000000000000]

a = decimal(a)
b = decimal(b)

print(a // b)
print(a % b)
# 1387736111563465