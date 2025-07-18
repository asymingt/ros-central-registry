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
#   mkdir -p ~/ros2_ws/src
#   cd ~/ros2_ws
#   rosinstall_generator ros_core --rosdistro rolling --deps --format repos  > ros2.repos
#   vcs import -w 1 --input ros2.repos src
#   rosdep update
#   rosdep install --from-paths src --ignore-src -y --skip-keys "fastcdr rti-connext-dds-7.3.0 urdfdom_headers"
#   colcon build --cmake-args --no-warn-unused-cli --graphviz=deps.dot -DBUILD_TESTING=ON
#
# RUN THIS SCRIPT:
#
#   python3 parse_ros_workspace.py ~/ros2_ws/build

import argparse
import logging
import sys
import shutil
from catkin_pkg.packages import find_packages
from bazel_ros.parse_cmake_project import parse_cmake_project
from bazel_ros.parse_setup_project import parse_setup_project
from bazel_ros.parse_ros_project import parse_ros_project
from pathlib import Path
from typing import Optional

from bazel_ros.spec import Interface, Load, Package, Workspace

def bazel_from_ros(
    repos_file : Path,
    ros_workspace : Path,
    bzl_workspace : Path = None, 
    pkg_name : Optional[str] = None,
    pkg_only : bool = False):
    """Parse the workspace at the given path and analyze its packages."""

    # Create a new workspace. This workspace will be passed by reference into the generators
    # to add information about the ROS build. At the end, the aggregated information will be
    # written to build files, so that we can `bazel build` the workspace.
    
    workspace = Workspace(
        name = "ros_central_registry",
        version = "0.0.0",
        python_version = "3.12",
        rules_python_version = "1.5.1",
    )

    # Make sure that we have a root bazel workspace.
    bzl_root = bzl_workspace / 'modules'
    bzl_root = bzl_root.mkdir(parents=True, exist_ok=True)

    # Start parsing the ROS workspace. We'll need to iterate over all catkin-discovered
    # packages and process them one-by-one.

    # Workspace paths
    ros_paths = {k : Path(ros_workspace / k) for k in ['src', 'build', 'install']}

    # Call catkin_pkg to find all packages in the source directory.
    i_packages = {p.name : p for p in find_packages(ros_workspace).values()}

    # Iterate over build directory to find all packages.
    o_packages = {p.name : p for p in ros_paths['build'].iterdir() if p.is_dir()}

    # Log the differences between the source and build packages.
    pkg_i = set(i_packages.keys())
    pkg_o = set(o_packages.keys())
    logging.info("The following packages differences were found:")
    logging.info(f'> in source but not in build: {list(pkg_i.difference(pkg_o))}')
    logging.info(f'> in build but not in source: {list(pkg_o.difference(pkg_i))}')

    # Limit to only the requested packages, if specified.
    all_packages = []
    for package in sorted(pkg_i):
        if pkg_name is not None:
            if pkg_only:
                if pkg_name != package:
                    continue
            elif pkg_name not in package:
                continue
        all_packages.append(package)
    if not all_packages:
        raise RuntimeError(f'Requested package {pkg_name} not found in workspace.')

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
        _, external_b_deps = process_dependencies(i_packages[pkg_name].build_depends)
        _, external_e_deps = process_dependencies(i_packages[pkg_name].exec_depends)
        for dep in external_b_deps.union(external_e_deps):
            if dep not in external_deps.keys():
                external_deps[dep] = set()
            external_deps[dep].add(pkg_name)

        # Get the source and build path for the current package
        pkg_src = Path(i_packages[pkg_name].filename).parent
        pkg_bld = o_packages[pkg_name]
        pkg_bzl = bzl_workspace / 'modules' / pkg_name

        # Make sure we have an output directory for the bazel files
        if not pkg_bzl.exists():
            logging.info(f"+ Created nonexistent output directory {pkg_bzl}")
            shutil.copytree(pkg_src, pkg_bzl)

        # Try and extract information about the dependencies and interfaces from the package.xml
        if not parse_ros_project(workspace=workspace, pkg_name=pkg_name, pkg_src=pkg_src):
            logging.warning(f'Skipping {pkg_name} because it is missing a package.xml file')

        # # If this is a python package then we should be able to find a setup.py file.
        # cmakelists_txt_path = Path(i_packages[pkg].filename).parent / 'CMakeLists.txt'
        # if cmakelists_txt_path.is_file():
        #     logging.info(f'[cmake] {pkg} [{i_packages[pkg].version}]')
        #     ret = parse_cmake_project(workspace, ros_paths, pkg, src_path, build_path)
        #     continue

        # # If this is a python package then we should be able to find a setup.py file.
        # setup_py_path = Path(i_packages[pkg].filename).parent / 'setup.py'
        # if setup_py_path.is_file():
        #     logging.info(f'+ [setup.py] {pkg} [{i_packages[pkg].version}]')
        #     ret = parse_setup_project(workspace, ros_paths, setup_py_path)
        #     logging.info(f'     data files:')
        #     for dst, src in ret.get('data_files', []):
        #         logging.info(f'     - {src} -> {dst}')
        #     logging.info(f'     packages:')
        #     for pkg in ret.get('packages', []):
        #         logging.info(f'     - {pkg}')
        #     logging.info(f'     entrypoints:')
        #     for command, values in ret.get('entry_points', {}).items():
        #         logging.info(f'     - {command}:')
        #         for value in values:
        #             logging.info(f'       {value}:')
        #     continue

        # # If this is a python package then we should be able to find a setup.py file.
        # setup_cfg_path = Path(i_packages[pkg].filename).parent / 'setup.cfg'
        # if setup_cfg_path.is_file():
        #     logging.info(f'[setup.cfg] {pkg} [{i_packages[pkg_name].version}]')
        #     continue

        # # We should never get here, but if we do then we don't know what this package is.
        # logging.error(f'[unknown] {pkg} [{i_packages[pkg_name].version}]')

    # Now, render everything to file!

    for pkg_name in sorted(workspace.packages.keys()):
        logging.info(f"Writing package: {pkg_name}")
        workspace.generate_package_files(
            pkg_name = pkg_name,
            module_file = bzl_workspace / 'modules' / pkg_name / 'MODULE.bazel',
            build_file = bzl_workspace / 'modules' / pkg_name / 'BUILD.bazel',
        )
    workspace.generate_workspace_files(
        build_file = bzl_workspace / 'BUILD.bazel',
        module_file = bzl_workspace / 'MODULE.bazel'
    )

if __name__ == '__main__':
    logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

    parser = argparse.ArgumentParser(description='A simple program that greets the user.')
    parser.add_argument('-r', '--repos', type=str, help='Path to the .repos file that build the ROS workspace')
    parser.add_argument('-w', '--workspace', type=str, help='Path to the ROS workspace, etg ~/ros_ws.')
    parser.add_argument('-b', '--bazel', type=str, help='Output folder for Bazel build dev env.')
    parser.add_argument('-p', '--package', type=str, default=None, help='Specific package to export')
    parser.add_argument('-o', '--only', action='store_true', help='Don\'t treat the package name as a wildcard')
    args = parser.parse_args()

    # Check that we have everything we need to build.
    for k in ['src', 'build', 'install']:
        assert (Path(args.workspace) / k).exists(), f"Path {args.workspace}/{k} does not exist."

    # Convert the ROS workspace to the bazel workspace.
    bazel_from_ros(
        repos_file = Path(args.repos),
        ros_workspace = Path(args.workspace),
        bzl_workspace = Path(args.bazel),
        pkg_name = args.package,
        pkg_only = args.only
    )
