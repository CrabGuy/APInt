def check_operations(file_name):
    file = open(file_name)
    lines = file.readlines()

    for index in range(len(lines)):
        line = lines[index]

        if len(line) == 1:
            continue

        tokens = line.split("=")
        assert len(tokens) == 2, "Invalid formatting"
        operations = tokens[0]
        result = eval(tokens[1])

        correct_result = eval(operations)

        assert correct_result == result, f"ERROR: line {index}\nOperation:\t{operations}\nCorrect result:\t{correct_result}\nResult got:\t{result}"

    file.close()

if __name__ == "__main__":
    check_operations("operations.txt")
    