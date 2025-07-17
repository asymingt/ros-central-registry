import logging
import setuptools
import sys
import os

def parse_setup_project(setup_py_filename):
    """
    Parses a setup.py file and returns the arguments passed to the setup() function.
    """
    setup_py_filename = os.path.abspath(setup_py_filename)
    package_path = os.path.dirname(setup_py_filename)
    setup_args = [None]

    # Backup the original setup function.
    old_path = sys.path
    old_argv = sys.argv
    old_setupfn = setuptools.setup

    # Keep track of the keyword args passed to setup()
    def patched_setup(**kwargs):
        setup_args[0] = kwargs

    # Patch the setup function to capture its arguments.
    os.chdir(package_path)
    sys.path = [package_path] + sys.path
    sys.argv = [setup_py_filename, "install"]
    setuptools.setup = patched_setup

    # Execute the setup.py file in our controlled context.
    with open(setup_py_filename) as f:
        exec(f.read(), {
            "__name__": "__main__",
            "__builtins__": __builtins__,
            "__file__": setup_py_filename
        })

    # Restore the original setup function.
    sys.path = old_path
    sys.argv = old_argv
    setuptools.setup = old_setupfn

    # Return a dictionary of the setup arguments.
    return setup_args[0]
