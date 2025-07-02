import logging
from cmake_file_api import CMakeProject, ObjectKind
from cmake_file_api.errors import CMakeException
from pathlib import Path

def _dict_from_project(pkg_name : str, cmake_project : CMakeProject):
    """Parse the CMake project and return its configuration."""
    for target in cmake_project.configurations[0].targets:

        ignore_targets = [
            'uninstall',
            f'{pkg_name}_uninstall',
            f'{pkg_name}__py',
            f'{pkg_name}__cpp',
            f'{pkg_name}__rs',
            f'{pkg_name}__rosidl_generator_c',
            f'{pkg_name}__rosidl_generator_py',
            f'{pkg_name}__rosidl_generator_type_description',
            f'{pkg_name}__rosidl_typesupport_c',
            f'{pkg_name}__rosidl_typesupport_cpp',
            f'{pkg_name}__rosidl_typesupport_fastrtps_c',
            f'{pkg_name}__rosidl_typesupport_fastrtps_cpp',
            f'{pkg_name}__rosidl_typesupport_fastrtps_c',
            f'{pkg_name}__rosidl_typesupport_introspection_c',
            f'{pkg_name}__rosidl_typesupport_introspection_cpp',
            f'{pkg_name}_s__rosidl_typesupport_c',
            f'{pkg_name}_s__rosidl_typesupport_fastrtps_c',
            f'{pkg_name}_s__rosidl_typesupport_fastrtps_cpp',
            f'{pkg_name}_s__rosidl_typesupport_introspection_c',
            f'{pkg_name}_s__rosidl_typesupport_introspection_cpp',
            f'ament_cmake_python_build_{pkg_name}_egg',
            f'ament_cmake_python_copy_{pkg_name}',
        ]
        if target.target.name in ignore_targets:
            continue

        logging.info(f"{target.target.type} :: {target.name}")

        try:
            logging.info("Input source files")
            for src in target.target.sources:
                logging.info(f"  <= {src.path}")
        except AttributeError as e:
            pass
        try:
            logging.info("Output install directories")
            destinations = set([
                f'{target.target.install.prefix}/{dst.path}' for dst in target.target.install.destinations
            ])
            for dst in destinations:
                logging.info(f"  => {dst}")
        except AttributeError as e:
            pass

def parse_cmake_project(pkg_name : str, src_path : Path, build_path : Path):
    cmake_project = CMakeProject(build_path, src_path, api_version=1)
    cmake_project.cmake_file_api.instrument(ObjectKind.CODEMODEL, 2)
    result = cmake_project.cmake_file_api.inspect(ObjectKind.CODEMODEL, 2)
    if not result:
        cmake_project.configure(quiet=True)
        result = cmake_project.cmake_file_api.inspect(ObjectKind.CODEMODEL, 2)
    return _dict_from_project(pkg_name, result)
        