# Copyright 2026 Open Source Robotics Foundation, Inc.
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

"""Expose the static Python import library so cc_import can link it on Windows.

On Windows the Python C API symbols are __declspec(dllimport), so an extension
module must link the Python import library (python3XY.lib) to resolve them
against the interpreter's DLL at load time. rules_python's current_py_cc_libs
provides that library, but only inside a CcInfo linking context whose owner is
not a node cc_shared_library recognises in its dependency graph -- so the
library is silently dropped from extension links and the PyErr_*/PyExc_* symbols
end up undefined.

This rule simply re-exports the import library's File in DefaultInfo. Feeding it
to a plain cc_import gives the library a genuine cc graph node, which
cc_shared_library links like any other static dependency.
"""

load("@rules_cc//cc:defs.bzl", "CcInfo")

def _py_import_lib_file_impl(ctx):
    for linker_input in ctx.attr.src[CcInfo].linking_context.linker_inputs.to_list():
        for lib in linker_input.libraries:
            static = lib.static_library or lib.pic_static_library
            if static and static.basename == ctx.attr.lib_name:
                return [DefaultInfo(files = depset(direct = [static]))]
    fail("import library %s not found in %s" % (ctx.attr.lib_name, ctx.attr.src.label))

py_import_lib_file = rule(
    implementation = _py_import_lib_file_impl,
    attrs = {
        "src": attr.label(
            mandatory = True,
            providers = [CcInfo],
            doc = "Typically @rules_python//python/cc:current_py_cc_libs.",
        ),
        "lib_name": attr.string(
            mandatory = True,
            doc = "Basename of the import library to re-export, e.g. python312.lib.",
        ),
    },
    doc = "Re-exports a single static import library File from a py_cc libs target.",
)
