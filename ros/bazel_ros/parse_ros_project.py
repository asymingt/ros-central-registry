import glob
import logging
import xml.etree.ElementTree as ET
from pathlib import Path

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
    deps = set()
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
                deps.add(f':msg__{parts[0]}')
            elif len(parts) == 2:
                deps.add(f'@{parts[0]}//:msg__{parts[1]}')
    return list(deps)

def parse_ros_project(workspace, pkg_name : str, src_path : Path, build_path : Path):
    package_xml_tree = ET.parse(src_path / 'package.xml')
    package_xml_root = package_xml_tree.getroot()
    has_interfaces = False
    for packages in package_xml_root.iter('package'):
        for buildtool_depend in packages.iter('buildtool_depend'):
            if buildtool_depend.text == 'rosidl_default_generators':
                has_interfaces = True
    messages = {}
    if has_interfaces:
        for ext in ['msg', 'srv', 'action', 'idl']:
            for path in glob.glob(f'{src_path}/**/*.{ext}', recursive=True):
                name = path.split('/')[-1].replace(f'.{ext}', '')
                messages[f':{ext}__{name}'] = {
                    "src" : path.removeprefix(f'{src_path}/'),
                    "deps" : get_dependencies(path),
                }
    return messages
