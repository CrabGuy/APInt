BASE = 2 ** 52

def f(arr):
    total = 0
    for index, num in enumerate(arr):
        total += num * (BASE ** index)
    return total

def factorial(x):
    if x <= 1:
        return 1
    return factorial(x - 1) * x


print(factorial(60))
print(f([0, 3496586634485440, 2043848730123309, 3657033000183100, 1533264680407645, 4491]))
# 265252859812191058636308480000000
# 265252859812191058636308480000000

"""print("number", number)
middle = (number - 10) // 2 + 10
print("middle", middle) """
# print(number)
# 225179981368524600
