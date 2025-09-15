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

load("@rosidl_cmake//:types.bzl", "RosInterfaceInfo")
load(":types.bzl", "RosIdlInfo")

# Calls the tool to generate a .idl file from the interface. Inputs:
#   executable   : the script to call
#   package_name : name of the package containing the interface
#   src          : path to input interface relative to Bazel working dir
#   dst          : path to output idl relative to Bazel working dir
def _generate(ctx, executable, package_name, src, dst, mnemonic):
    ctx.actions.run_shell(
        command = "{exec} -p {src_dir} -n {pkg} {src_name} {dst_dir} {out}".format(
            exec = executable.path,
            src_dir = src.dirname,
            pkg = package_name,
            src_name = src.basename,
            dst_dir = dst.dirname,
            out = "> /dev/null 2>&1"
        ),
        tools = [executable],
        inputs = [src],
        outputs = [dst],
        mnemonic = mnemonic,
        progress_message = "Generating IDL files for {}".format(ctx.label.name),
    )

# This would be better expressed as a regex operation, but unfortunately Bazel's
# starlark language does not yet support this, and so it would require a module.
# For example: https://github.com/magnetde/starlark-re/tree/master
def _snake_case_from_pascal_case(pascal_case):
    result = ""
    pascal_case_padded = " " + pascal_case + " "
    for i in range(len(pascal_case)):
        prev_char, char, next_char = pascal_case_padded[i:i + 3].elems()
        if char.isupper() and next_char.islower() and prev_char != " ":
            # Insert an underscore before any upper case letter which is not
            # followed by another upper case letter.
            result += "_"
        elif char.isupper() and (prev_char.islower() or prev_char.isdigit()):
            # Insert an underscore before any upper case letter which is
            # preseded by a lower case letter or number.
            result += "_"
        result += char.lower()
    return result

def _idl_adapter_aspect_impl(target, ctx):
    # The last element of the traversal order of the message depset is the current element.
    src = target[RosInterfaceInfo].srcs.to_list()[-1]

    # Calculate the metadata to package alongside the IDL.
    package_name = target[RosInterfaceInfo].package                 # eg. sensor_msgs
    interface_type = src.extension                                  # eg. msg
    interface_name = src.basename[:-len(src.extension) - 1]         # eg. CompressedImage
    interface_code = _snake_case_from_pascal_case(interface_name)   # eg. compressed_image

    # Now, were going to transform the source file (msg, srv, action) to an IDL.
    idl = ctx.actions.declare_file(
        "{}/{}/{}.idl".format(package_name, interface_type, interface_name)
    )

    if src.extension == 'msg':
        _generate(ctx, ctx.executable._msg2idl, package_name, src, idl, "IdlFromMsg")
    elif src.extension == 'srv':
        _generate(ctx, ctx.executable._srv2idl, package_name, src, idl, "IdlFromSrv")
    elif src.extension == 'action':
        _generate(ctx, ctx.executable._action2idl, package_name, src, idl, "IdlFromAction")
    else:
        fail('Unknown file extension: ' + src.extension)
    return [
        RosIdlInfo(
            idls = depset(
                direct = [idl],
                transitive = [
                    dep[RosIdlInfo].idls for dep in ctx.rule.attr.deps if RosIdlInfo in dep
                ],
            ),
            interface_type = interface_type,
            interface_name = interface_name,
            interface_code = interface_code,
            package_name = package_name,
        ),
    ]

# IDL aspect runs along the deps property to generate IDLs for each RosInterface,
# through one of the three cli tools, producing a ROS IDL for each one.
idl_aspect = aspect(
    implementation = _idl_adapter_aspect_impl,
    attr_aspects = ["deps"],
    attrs = {
        "_msg2idl": attr.label(
            default = Label("//:msg2idl"),
            executable = True,
            cfg = "exec",
        ),
        "_srv2idl": attr.label(
            default = Label("//:srv2idl"),
            executable = True,
            cfg = "exec",
        ),
        "_action2idl": attr.label(
            default = Label("//:action2idl"),
            executable = True,
            cfg = "exec",
        ),
    },
    required_providers = [RosInterfaceInfo],
    provides = [RosIdlInfo],
)
