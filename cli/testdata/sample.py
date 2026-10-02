"""A small sample module."""
import sys


class Greeter:
    def __init__(self, name: str) -> None:
        self.name = name

    def greet(self, times: int = 1) -> str:
        if times > 1:
            return " ".join(f"Hello, {self.name}!" for _ in range(times))  # a long line that will need wrapping
        return f"Hello, {self.name}!"


if __name__ == "__main__":
    print(Greeter(sys.argv[1]).greet(2))
