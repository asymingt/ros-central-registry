import logging
from cmake_file_api import CMakeProject, ObjectKind
from cmake_file_api.errors import CMakeException
from cmake_file_api.kinds.codemodel.target.v2 import TargetType
from pathlib import Path

def _dict_from_project(workspace, pkg_name : str, cmake_project : CMakeProject, build_path : Path):
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
            f'ament_generate_version_header__{pkg_name}',
        ]
        if target.target.name in ignore_targets:
            continue
        if target.target.type == TargetType.UTILITY:
            continue

        logging.info(f"+ {target.target.type} :: {target.name}")
        #logging.info(f"+ {target.target}")
        #import pdb; pdb.set_trace()

        try:
    
            logging.info("  Output install directories:")
            destinations = set([
                f'{target.target.install.prefix}/{dst.path}' for dst in target.target.install.destinations
            ])
            for dst in sorted(destinations):
                logging.info(f"  - {dst}")
        
            for compileGroups in target.target.compileGroups:
                fragments = ", ".join([f.fragment for f in compileGroups.compileCommandFragments])
                logging.info(f"  Flags:  {fragments}")
                logging.info("  Preprocessor directives: ")
                for defines in compileGroups.defines:
                    logging.info(f"  - {defines.define} ")
                logging.info("  Include folders: ")
                for include in compileGroups.includes:
                    include_str = str(include)
                    if "rosidl_dynamic_typesupport" in include_str:
                        continue
                    if "rosidl_typesupport" in include_str:
                        continue
                    if "rosidl_generator" in include_str:
                        continue
                    logging.info(f"  - {include.path} ")
                # logging.info("  srcs =  ")
                # for source in compileGroups.sources:
                #     logging.info(f"  - {source.path} ")
            if target.target.link:
                logging.info(f"  deps = ")
                for fragment in target.target.link.commandFragments:
                    fragment_str = str(fragment.fragment)
                    if "rosidl_dynamic_typesupport" in fragment_str:
                        continue
                    if "rosidl_typesupport" in fragment_str:
                        continue
                    if "rosidl_generator" in fragment_str:
                        continue
                    if fragment_str.startswith("-Wl,-rpath"):
                        continue
                    if fragment_str in [""]:
                        continue
                    if fragment_str.startswith(str(workspace['install'])):
                        ros_lib = fragment_str.replace(str(workspace['install']) + '/', '')
                        parts = ros_lib.split('/')
                        ros_pkg = parts[0]
                        ros_lib = parts[2][3:].rsplit('.')[0]
                        logging.info(f"  - @{ros_pkg}//:{ros_lib}")
                        continue
                    logging.info(f"  - {fragment.fragment}")

            destinations_raw = set()
            destinations_gen = set()
            for src in target.target.sources:
                if str(src.path).endswith(".rule"):
                    continue
                if str(src.path).startswith(str(build_path)):
                    destinations_gen.add(str(src.path)[len(str(build_path)) + 1: ])
                else:
                    destinations_raw.add(str(src.path))
            if len(destinations_raw) > 0:
                logging.info("  Raw sources: ")
                for dst in sorted(destinations_raw):
                    logging.info(f"  + {dst}")
            if len(destinations_gen) > 0:
                logging.info("  Generated sources: ")
                for dst in sorted(destinations_gen):
                    logging.info(f"  + {dst}")
        except AttributeError as e:
            pass


def parse_cmake_project(workspace, pkg_name : str, src_path : Path, build_path : Path):
    cmake_project = CMakeProject(build_path, src_path, api_version=1)
    cmake_project.cmake_file_api.instrument(ObjectKind.CODEMODEL, 2)
    result = cmake_project.cmake_file_api.inspect(ObjectKind.CODEMODEL, 2)
    if not result:
        cmake_project.configure(quiet=True)
        result = cmake_project.cmake_file_api.inspect(ObjectKind.CODEMODEL, 2)
    return _dict_from_project(workspace, pkg_name, result, build_path)
        