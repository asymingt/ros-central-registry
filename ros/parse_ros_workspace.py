#!/usr/bin/env python3
#
# This python script analyzes a prebuilt ROS2 workspace for information about how it was built. To do this requires
# building the workspace with specific colcon flags. Under the hood, this enables the CMake File API, which is a
# standardized way to query CMake projects for their build information. The output is written to a JSON file, 
# which we can then query using the cmake_file_api module
#
# INSTALL TOOLING
#
#   sudo apt install python3-rosinstall-generator
#
# PREPARE THE WORKSPACE:
#
#   mkdir -p ~/ros2_ws/src && cd ~/ros2_ws
#   rosinstall_generator ros_core --rosdistro rolling --deps --format repos  > ros2.repos
#   vcs import -w 1 --input ros2.repos src
#   rosdep install --from-paths src --ignore-src -y --skip-keys "fastcdr rti-connext-dds-7.3.0 urdfdom_headers"
#   colcon build --cmake-args --no-warn-unused-cli --graphviz=deps.dot -DBUILD_TESTING=OFF
#
# RUN THIS SCRIPT:
#
#   python3 parse_ros_workspace.py ~/ros2_ws/build

import argparse
import logging
import sys
from catkin_pkg.packages import find_packages
from bazel_ros.parse_cmake_project import parse_cmake_project
from bazel_ros.parse_setup_project import parse_setup_project
from bazel_ros.parse_ros_project import parse_ros_project
from pathlib import Path


def parse_workspace(path : Path, package_name : str = None, specific_package : bool = False):
    """Parse the workspace at the given path and analyze its packages."""

    # Workspace paths
    workspace = {k : Path(path / k) for k in ['src', 'build', 'install']}

    # Call catkin_pkg to find all packages in the source directory.
    i_packages = {p.name : p for p in find_packages(path).values()}

    # Iterate over build directory to find all packages.
    o_packages = {p.name : p for p in workspace['build'].iterdir() if p.is_dir()}

    # Log the differences between the source and build packages.
    pkg_i = set(i_packages.keys())
    pkg_o = set(o_packages.keys())
    logging.info("The following packages differences were found:")
    logging.info(f'> in source but not in build: {list(pkg_i.difference(pkg_o))}')
    logging.info(f'> in build but not in source: {list(pkg_o.difference(pkg_i))}')

    # Limit to only the requested packages, if specified.
    all_packages = []
    for package in sorted(pkg_i):
        if package_name is not None:
            if specific_package:
                if package_name != package:
                    continue
            elif package_name not in package:
                continue
        all_packages.append(package)
    if not all_packages:
        raise RuntimeError(f'Requested package {package_name} not found in workspace.')

    def process_dependencies(deplist):
        """Processes a list of dependencies and separates them into internal and external dependencies."""
        internal_deps = set()
        external_deps = set()
        for dep in deplist:
            if dep.name not in i_packages:
                external_deps.add(dep.name)
            else:
                internal_deps.add(dep.name)
        return internal_deps, external_deps


    # Process each package in the workspace
    logging.info("Processing packages:")
    external_deps = {}
    for pkg_name in all_packages:
        internal_b_deps, external_b_deps = process_dependencies(i_packages[pkg_name].build_depends)
        internal_e_deps, external_e_deps = process_dependencies(i_packages[pkg_name].exec_depends)
        for dep in external_b_deps.union(external_e_deps):
            if dep not in external_deps.keys():
                external_deps[dep] = set()
            external_deps[dep].add(pkg_name)
        
        # Get the source and build path.
        src_path = Path(i_packages[pkg_name].filename).parent
        build_path = o_packages[pkg_name]

        # Open up the package.xml to discover pa
        package_xml_file = Path(i_packages[pkg_name].filename).parent / 'package.xml'
        if package_xml_file.is_file():
            messages  = parse_ros_project(workspace, pkg_name, src_path, build_path)
            if messages:
                logging.info(f'+ [package] has interfaces')
                for msg in sorted(messages.keys()):
                    info = messages[msg]
                    logging.info(f'   {msg} [{info["src"]}]')
                    for dep in sorted(info["deps"]):
                        logging.info(f'      - {dep}')
            else:
                logging.info(f'[package] has no interfaces')
        else:
            logging.warning(f'Skipping {pkg_name} because it is missing a package.xml file')

        # If this is a python package then we should be able to find a setup.py file.
        cmakelists_txt_path = Path(i_packages[pkg_name].filename).parent / 'CMakeLists.txt'
        if cmakelists_txt_path.is_file():
            logging.info(f'[cmake] {pkg_name} [{i_packages[pkg_name].version}]')
            ret = parse_cmake_project(workspace, pkg_name, src_path, build_path)
            continue

        # If this is a python package then we should be able to find a setup.py file.
        setup_py_path = Path(i_packages[pkg_name].filename).parent / 'setup.py'
        if setup_py_path.is_file():
            logging.info(f'+ [setup.py] {pkg_name} [{i_packages[pkg_name].version}]')
            ret = parse_setup_project(setup_py_path)
            logging.info(f'     data files:')
            for dst, src in ret.get('data_files', []):
                logging.info(f'     - {src} -> {dst}')
            logging.info(f'     packages:')
            for pkg in ret.get('packages', []):
                logging.info(f'     - {pkg}')
            logging.info(f'     entrypoints:')
            for command, values in ret.get('entry_points', {}).items():
                logging.info(f'     - {command}:')
                for value in values:
                    logging.info(f'       {value}:')
            continue

        # If this is a python package then we should be able to find a setup.py file.
        setup_cfg_path = Path(i_packages[pkg_name].filename).parent / 'setup.cfg'
        if setup_cfg_path.is_file():
            logging.info(f'[setup.cfg] {pkg_name} [{i_packages[pkg_name].version}]')
            continue

        # We should never get here, but if we do then we don't know what this package is.
        logging.error(f'[unknown] {pkg_name} [{i_packages[pkg_name].version}]')


if __name__ == '__main__':
    logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

    parser = argparse.ArgumentParser(description='A simple program that greets the user.')
    parser.add_argument('workspace', type=str, help='Path to the workspace.')
    parser.add_argument('-p', '--package', type=str, default=None, help='Specific package to analyze')
    parser.add_argument('-o', '--output', type=str, default=None, help='Output for example MODULE.bzl file')
    parser.add_argument('-s', '--specific', action='store_true', help='Package is a specific name, not a substring')
    args = parser.parse_args()

    parse_workspace(Path(args.workspace), args.package, args.specific)
    
# Print out external dependencies.
# logging.info(f'External build dependencies:')
# for dep_name in sorted(external_deps.keys()):
#     logging.info(f'+ {dep_name} : {external_deps[dep_name]}')

# pkg_i = set()
# for path in glob.glob('/home/ros/workspaces/feature/my-new-feature/src/**/package.xml', recursive=True):
#     read_package_xml(path)

#     if not ((Path(path).parent / 'COLCON_IGNORE').is_file() or (Path(path).parent / 'AMENT_IGNORE').is_file()):
#         pkg_i.add(Path(path).parent.name)
# pkg_o = set([file_path.name for file_path in Path('/home/ros/workspaces/feature/my-new-feature/build').iterdir() if file_path.is_dir()])

# print(sorted(pkg_i.difference(pkg_o)))

    #print(f'processing: {package_path.name}')
    # cmake_project = CMakeProject(package_path, None, api_version=1)
    # try:
    #     cmake_project.cmake_file_api.inspect(ObjectKind.CODEMODEL, 2)
    #     continue
    # except CMakeException as e:
    #     print(f"Error processing {package_path.name}: {e}")
    #     continue



# dst_path = Path('/home/ros/workspaces/feature/my-new-feature/build')

# packages = sorted([file_path for file_path in dst.iterdir() if file_path.is_dir()])

# for package in packages:
#     print(f'processing: {package.name}')
#     cmake_project = CMakeProject(package, None, api_version=1)
#     try:
#         cmake_project.cmake_file_api.inspect(ObjectKind.CODEMODEL, 2)
#         continue
#     except CMakeException as e:
#         continue

# print(packages)
#     # if file_path.is_dir(): # Check if the path points to a file
#     #     print(file_path.name) # Prints the Path object, which can be converted to a string