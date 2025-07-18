import logging
from dataclasses import dataclass, field
from collections import defaultdict
from typing import List, Optional, Set
from pathlib import Path

COPYRIGHT_HEADER = """
# Copyright 2025 Open Source Robotics Foundation, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""

@dataclass(repr=False)
class Load:
    """Stored information about .bzl file loads"""
    direct: Set[str] = field(default_factory=set)
    remaps: defaultdict[str, str] = field(default_factory=lambda: defaultdict(str))
    def __str__(self):
        function_strings = []
        for f in self.direct:
            function_strings.append(f'"{f}"')
        for k, v in self.remaps.items():
            function_strings.append(f'{k} = "{v}"')
        return ", ".join(function_strings)

@dataclass(repr=False)
class Interface:
    """Stores information about a ROS interface"""
    src: str
    int_deps: Set[str] = field(default_factory=set)
    ext_deps: defaultdict[str, Set[str]] = field(default_factory=lambda: defaultdict(set))
    def __str__(self):
        dep_string = ""
        if len(self.int_deps) + len(self.ext_deps) > 0:
            dep_string += "    deps = ["
            for pkg in sorted(self.ext_deps.keys()):
                for msg in sorted(self.ext_deps[pkg]):
                    dep_string += f'\n        "@{pkg}//:msg__{msg}",'
            for msg in sorted(self.int_deps):
                dep_string += f'\n        ":msg__{msg}",'
            dep_string += '\n    ],\n'
        return dep_string

@dataclass(repr=False)
class Package:
    version: Optional[str] = None
    loads: defaultdict[str, Load] = field(default_factory=lambda: defaultdict(Load))
    interfaces : defaultdict[str, Interface] = field(default_factory=lambda: defaultdict(Interface))

@dataclass(repr=False)
class Workspace:
    name: str
    version: str
    packages: defaultdict[str, Package] = field(default_factory=lambda: defaultdict(Package))
    compatibility_level : int = 1
    python_version : str = "3.12"
    rules_python_version : str = "1.5.1"

    def _generate_package_build_file(self, pkg_name : str, build_file : Path):
        """Generate the BUILD.bazel file for the given ROS package"""
        if pkg_name not in self.packages.keys():
            raise RuntimeError(f"could not find {pkg_name} in the list of packages")
        package = self.packages[pkg_name]
        build_string = COPYRIGHT_HEADER
        if package.loads:
            build_string += "\n# Imports\n\n"
            for k, v in package.loads.items():
                build_string += f'load("{k}", {str(v)})\n'
        if package.interfaces:
            build_string += "\n# Interfaces\n"
            for interface_name, interface_info in package.interfaces.items():
                interface_type = Path(interface_info.src).suffix[1:]
                interface_deps = str(interface_info)
                build_string += f"""
ros_interface(
    name = ":{interface_type}__{interface_name}",
    src = "{interface_info.src}",
    visibility = ["//visibility:public"],
{interface_deps})\n"""
        with open(build_file, "w") as f:
            f.write(build_string)

    def _generate_package_module_file(self, pkg_name : str, module_file : Path):
        """Generate the MODULE.bazel file for the given ROS package"""
        if pkg_name not in self.packages.keys():
            raise RuntimeError(f"could not find {pkg_name} in the list of packages")
        package = self.packages[pkg_name]
        deps = set()
        for interface_info in package.interfaces.values():
            for pkg in interface_info.ext_deps.keys():
                deps.add(pkg)
        dep_string = ""
        for dep in sorted(deps):
            dep_string += f'\nbazel_dep(name = "{dep}", version = "{self.packages[dep].version}")'
        module_string = f"""{COPYRIGHT_HEADER}
# Package information
        
module(
    name = "{pkg_name}",
    version = "{package.version}",
    compatibility_level = {self.compatibility_level},
)

# Dependencies
{dep_string}"""
        with open(module_file, "w") as f:
            f.write(module_string)

    def _generate_workspace_build_file(self, build_file : Path):
        """Generate the BUILD.bazel file for the workspace"""
        build_string = COPYRIGHT_HEADER
        with open(build_file, "w") as f:
            f.write(build_string)


    def _generate_workspace_module_file(self, module_file : Path):
        """Generate the MODULE.bazel file for the workspace"""
        dep_string = ""
        module_string = f"""{COPYRIGHT_HEADER}
module(
    name = "{self.name}",
    version = "{self.version}",
    compatibility_level = {self.compatibility_level},
)
{dep_string}

bazel_dep(name = "rules_python", version = "{self.rules_python_version}")

python = use_extension("@rules_python//python/extensions:python.bzl", "python")
python.toolchain(
    python_version = "{self.python_version}",
    is_default = True,
)
"""
        with open(module_file, "w") as f:
            f.write(module_string)

    def generate_package_files(self, pkg_name : str, build_file : Optional[Path] = None, module_file : Optional[Path] = None):
        """Generate all Bazel files for the specified ROS package"""
        if build_file:
            self._generate_package_build_file(pkg_name, build_file)
        if module_file:
            self._generate_package_module_file(pkg_name, module_file)

    def generate_workspace_files(self, build_file : Optional[Path] = None, module_file : Optional[Path] = None):
        """Generate all Bazel files for the workspace"""
        if build_file:
            self._generate_workspace_build_file(build_file)
        if module_file:
            self._generate_workspace_module_file(module_file)
