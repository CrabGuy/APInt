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

number = factorial(100)
#      [958209396572160, 540]
test = [0, 457396837154816, 4093494308582854, 3499518875331886, 2046565016048672, 1023790514504593, 2938904952287892, 2886018014801657, 1133137611803581, 854753994694082, 27]
print(number == f(test))
print(number)
print(f(test))
print(inverse_f(number))
print(test)
#       [4, 4503599627370492]
