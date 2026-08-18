import subprocess
import sys
import os

def run():
    lua_test = subprocess.run(["lua", "test.lua"])
    if lua_test.returncode != 0:
        print("LuaUnit tests failed.")
        sys.exit(1)

    gen_ops = subprocess.run(["lua", "random_operations.lua"])
    if gen_ops.returncode != 0:
        print("Failed to generate random operations.")
        sys.exit(1)

    check_ops = subprocess.run(["python3", "check_operations.py", "operations.txt"])
    if check_ops.returncode != 0:
        print("Check operations failed.")
        sys.exit(1)

    print("\n--- All correctness tests passed! ---")

if __name__ == "__main__":
    run()