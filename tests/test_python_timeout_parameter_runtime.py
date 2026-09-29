"""Runtime probe for Python-app timeout parameter admission."""

import unittest

from parsl.app.errors import AppTimeout
from parsl.app.python import timeout


class PythonTimeoutParameterRuntimeTest(unittest.TestCase):
    def test_negative_timeout_injects_immediate_app_timeout_currently(self):
        wrapped = timeout(lambda: "done", -1)
        with self.assertRaises(AppTimeout):
            wrapped()


if __name__ == "__main__":
    unittest.main()
