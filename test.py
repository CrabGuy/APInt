BASE = 2 ** 52

def f(arr):
    total = 0
    for index, num in enumerate(arr):
        total += num * (BASE ** index)
    return total

def inverse_f(x, base=BASE):
    if x < 0:
        raise ValueError("Only non-negative integers are supported")

    arr = []
    while x > 0:
        x, digit = divmod(x, base)
        arr.append(digit)
    return arr

def factorial(x):
    if x <= 1:
        return 1
    return factorial(x - 1) * x

# print(factorial(60))
# [0, 4472561264986224, 2043848730123310, 3657033000183100, 1533264680407645, 4491]
number = (BASE // 2 + 1) ** 3
test = [1, 2251799813685250, 2251799813685249, 281474976710656]
print(number == f(test))
print(number)
print(f(test))
print(inverse_f(number))
print(test)
#       [4, 4503599627370492]
