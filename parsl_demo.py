"""The concrete four-task workflow represented by ParslAbstract.tla.

Run with ``python3 parsl_demo.py`` after installing Parsl.  The model checker
does not execute this program; this file makes the abstraction-to-code mapping
easy to compare with a real Parsl dataflow graph.
"""

import parsl
from parsl.app.app import python_app
from parsl.config import Config
from parsl.executors.threads import ThreadPoolExecutor


@python_app
def make_a():
    return "A"


@python_app
def make_b(a):
    return a + "B"


@python_app
def make_c(a):
    return a + "C"


@python_app
def make_d(b, c):
    return b + c + "D"


if __name__ == "__main__":
    parsl.load(Config(executors=[ThreadPoolExecutor(max_threads=2)]))
    a = make_a()
    b = make_b(a)
    c = make_c(a)
    d = make_d(b, c)
    print(d.result())
    parsl.clear()
