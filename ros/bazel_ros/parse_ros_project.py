import glob
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict
from bazel_ros.spec import Interface, Package, Workspace
from collections import defaultdict

BUILTINS = [
    'bool',
    'byte',
    'char',
    'float32',
    'float64',
    'int8',
    'uint8',
    'int16',
    'uint16',
    'int32',
    'uint32',
    'int64',
    'uint64',
    'string',
    'wstring'
]

def get_dependencies(interface_path : Path):
    int_deps = set()
    ext_deps = defaultdict(set)
    with open(interface_path) as f:
        for line in f.readlines():
            stripped_line = line.strip()
            # Remove comments and dividers
            if len(stripped_line) == 0 or stripped_line[0] in ['#', '-']:
                continue
            # Remove array-style modifiers
            tokens = stripped_line.split(' ')
            lntype = tokens[0]
            if '[' in lntype:
                lntype = lntype[0:tokens[0].find('[')]
            # Filter out builtin types
            if lntype in BUILTINS:
                continue
            # Handle the various ref styles
            parts = lntype.split('/')
            if len(parts) == 1:
                int_deps.add(parts[0])
            elif len(parts) == 2:
                ext_deps[parts[0]].add(parts[1])
            else:
                raise RuntimeError(f"Cannot decode field: {stripped_line}")
    return int_deps, ext_deps

def parse_ros_project(workspace : Workspace, pkg_name : str, pkg_src : Path):
    package_xml_file = pkg_src / 'package.xml'
    if not package_xml_file.exists():
        return False
    package_xml_root = ET.parse(package_xml_file).getroot()
    for packages in package_xml_root.iter('package'):
        for version in packages.iter('version'):
            workspace.packages[pkg_name].version = version.text
            workspace.packages[pkg_name].loads['@ros//:defs.bzl'].direct.add("ros_package")
        for buildtool_depend in packages.iter('buildtool_depend'):
            if buildtool_depend.text == 'rosidl_default_generators':
                workspace.packages[pkg_name].loads['@ros//:defs.bzl'].direct.add("ros_interface")
                for ext in ['msg', 'srv', 'action']:
                    for path in glob.glob(f'{pkg_src}/**/*.{ext}', recursive=True):
                        int_name = path.split('/')[-1].replace(f'.{ext}', '')
                        int_deps, ext_deps = get_dependencies(path)
                        workspace.packages[pkg_name].interfaces[int_name] = Interface(
                            src = str(path.removeprefix(f'{pkg_src}/')),
                            int_deps = int_deps,
                            ext_deps = ext_deps,
                        )
    return True
