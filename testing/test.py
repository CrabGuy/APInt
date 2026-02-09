BASE = 2**52

def decimal(digits):
    return sum(digit * (BASE**i) for i, digit in enumerate(digits))

result_got = decimal([0, 4419942254379008, 1218062511332401, 2252745923636380, 1562451958731451, 5397605])
correct_result = ((10 ** 100) // (10 ** 15))
print(BASE)
print(result_got == correct_result)
print(result_got)
print(correct_result)

""" a = decimal([1, 2, 3])
b = decimal([2251799813685249])
multiplier = 1


print("q = ", decimal([4503599627370488, 5]))
print("r = ", decimal([11, 1]))

print("Division: \t", a // b)
print("Modulo: \t", a % b)
print("Modulo devided:\t", (a % b) // multiplier)
print("actual modulo\t", (a // multiplier) % (b // multiplier))
 """