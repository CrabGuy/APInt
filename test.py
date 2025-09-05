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

number = f([2310042140305905, 3779025547483650, 2759084521790143, 1333207883151640, 2871280155256532, 2361179593819894]) // f([4380989235077369, 1317378481282125, 3473886240354038])
test = [2207699368668999, 1088890344862023, 3061069592710198]
print(number == f(test))
print(number)
print(f(test))
print(inverse_f(number))
print(test)
#       [4, 4503599627370492]
