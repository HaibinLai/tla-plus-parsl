"""Runtime probe for cyclic Python object graphs in Parsl serialization."""

import unittest

from parsl.serialize.facade import serialize, deserialize


class PythonCyclicObjectRuntimeTest(unittest.TestCase):
    def test_dill_round_trip_preserves_internal_cycles(self):
        cyclic_argument = []
        cyclic_argument.append(cyclic_argument)

        decoded_argument = deserialize(serialize(cyclic_argument))

        self.assertIs(decoded_argument[0], decoded_argument)


if __name__ == "__main__":
    unittest.main()
