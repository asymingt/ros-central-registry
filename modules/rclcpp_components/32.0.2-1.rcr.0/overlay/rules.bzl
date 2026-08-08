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

load("@rosdistro//cc:defs.bzl", "collect_transitive_dynamic_deps", "ros_local_defines")
load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@rules_cc//cc/common:cc_shared_library_info.bzl", "CcSharedLibraryInfo")

# Generate a node main .cpp file.

def _component_node_main_gen_impl(ctx):
    lib_path = ctx.attr.component[CcSharedLibraryInfo].linker_input.libraries[0].dynamic_library
    ctx.actions.expand_template(
        template = ctx.file._node_template,
        output = ctx.outputs.output,
        substitutions = {
            "@node@": ctx.attr.node_name,
            "@executor@": "rclcpp::executors::{0}".format(ctx.attr.executor),
            "@library_name@": lib_path.basename,
            "@component@": ctx.attr.plugin,
        },
    )
    return [
        DefaultInfo(files = depset([ctx.outputs.output])),
    ]

_component_node_main_gen = rule(
    implementation = _component_node_main_gen_impl,
    attrs = {
        "output": attr.output(mandatory = True),
        "node_name": attr.string(mandatory = True),
        "plugin": attr.string(mandatory = True),
        "component": attr.label(
            mandatory = True,
            providers = [CcSharedLibraryInfo],
        ),
        "executor": attr.string(default = "SingleThreadedExecutor"),
        "_node_template": attr.label(
            default = Label(":src/node_main.cpp.in"),
            allow_single_file = True,
        ),
    },
    provides = [DefaultInfo],
)

def _component_record_gen_impl(ctx):
    lib_path = ctx.attr.component[CcSharedLibraryInfo].linker_input.libraries[0].dynamic_library
    content = "{0};lib/{1}\n".format(ctx.attr.plugin, lib_path.basename)
    output_file = ctx.actions.declare_file(ctx.attr.name + ".component")
    ctx.actions.write(
        output = output_file,
        content = content,
    )
    return [DefaultInfo(files = depset([output_file, lib_path]))]

_component_record_gen = rule(
    implementation = _component_record_gen_impl,
    attrs = {
        "plugin": attr.string(mandatory = True),
        "component": attr.label(
            mandatory = True,
            providers = [CcSharedLibraryInfo],
        ),
    },
)

def rclcpp_components_register_node(name, component, plugin, node_name = None, executor = "SingleThreadedExecutor"):
    record_name = name + "_record"
    _component_record_gen(
        name = record_name,
        plugin = plugin,
        component = component,
    )

    if node_name:
        src_name = name + "_main.cpp"
        _component_node_main_gen(
            name = name + "_gen",
            output = src_name,
            node_name = node_name,
            component = component,
            plugin = plugin,
            executor = executor,
        )
        collect_transitive_dynamic_deps(
            name = name + "_transitive",
            dynamic_deps = [component],
        )
        cc_binary(
            name = name,
            srcs = [src_name],
            deps = ["@rclcpp_components//:rclcpp_components_library"],
            dynamic_deps = ["{0}_transitive".format(name)],
            data = [":" + record_name],
        )

def rclcpp_components_register_nodes(name, component, plugins):
    record_names = []
    for plugin in plugins:
        plugin_name = "{0}_{1}".format(name, plugin.replace(":", "_"))
        rclcpp_components_register_node(
            name = plugin_name,
            component = component,
            plugin = plugin,
        )
        record_names.append("{0}_record".format(plugin_name))
    native.filegroup(
        name = name,
        srcs = [":" + r for r in record_names],
    )
