BASE = 2 ** 52

def f(arr, base=BASE):
    total = 0
    for index, num in enumerate(arr):
        total += num * (base ** index)
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

number = 2 ** 53
test = [0]
print(number == f(test))
print(number)
print(f(test))
print(inverse_f(number))
print(test)
#       [4, 4503599627370492]
