BASE = 2 ** 51

def f(arr):
    total = 0
    for index, num in enumerate(arr):
        total += num * (BASE ** index)
    return total

number = (BASE - 2) * 100
"""print("number", number)
middle = (number - 10) // 2 + 10
print("middle", middle) """
print(number)
# 225179981368524600
