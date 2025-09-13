
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

load("@rules_cc//cc:defs.bzl", "CcInfo")
load("@rules_cc//cc:find_cc_toolchain.bzl", "use_cc_toolchain")
load("@rosidl_cmake//:types.bzl", "RosInterfaceInfo")
load("@rosidl_adapter//:types.bzl", "RosIdlInfo")
load("@rosidl_adapter//:tools.bzl", "generate_sources", "generate_cc_info")
load("@rosidl_generator_type_description//:types.bzl", "RosTypeDescriptionInfo")
load(":types.bzl", "RosCcBindingsInfo")

def _cc_aspect_impl(target, ctx):
    input_idls = target[RosIdlInfo].idls.to_list()
    input_type_descriptions = target[RosTypeDescriptionInfo].jsons.to_list()

    # Generate the C++ bindings
    hdrs, srcs, include_dir = generate_sources(
        target = target,
        ctx = ctx,
        executable = ctx.executable._cc_generator,
        mnemonic = "CcGeneration",
        input_idls = input_idls,
        input_type_descriptions = input_type_descriptions,
        input_templates = ctx.attr._cc_templates[DefaultInfo].files.to_list(),
        templates_hdrs = [
            "{}.hpp",
            "detail/{}__builder.hpp",
            "detail/{}__struct.hpp",
            "detail/{}__traits.hpp",
            "detail/{}__type_support.hpp",
        ],
        templates_srcs = [],
        template_visibility_control = ctx.file._cc_visibility_template,
    )
    
    # These deps will all have CcInfo providers.
    deps = [dep[CcInfo] for dep in ctx.attr._cc_deps if CcInfo in dep] 
    for dep in ctx.rule.attr.deps:
        if RosCcBindingsInfo in dep:
            deps.extend([d for d in dep[RosCcBindingsInfo].cc_infos.to_list()])
    
    # Merge headers, sources and deps into a CcInfo provider.
    cc_info = generate_cc_info(
        ctx = ctx,
        name = "{}_c".format(ctx.label.name),
        hdrs = hdrs,
        srcs = srcs,
        deps = deps,
        include_dirs = [include_dir],
    )

    # Return a CcInfo provider for the aspect.
    return [
        RosCcBindingsInfo(
            cc_infos = depset(
                direct = [cc_info],
                transitive = [
                    dep[RosCcBindingsInfo].cc_infos
                        for dep in ctx.rule.attr.deps if RosCcBindingsInfo in dep
                ],
            ),
            cc_files = depset(
                direct = hdrs + srcs,
                transitive = [
                    dep[RosCcBindingsInfo].cc_files
                        for dep in ctx.rule.attr.deps if RosCcBindingsInfo in dep
                ],
            ),
        )
    ]

cc_aspect = aspect(
    implementation = _cc_aspect_impl,
    toolchains = use_cc_toolchain(),
    attr_aspects = ["deps"],
    fragments = ["cpp"],
    attrs = {
        "_cc_generator": attr.label(
            default = Label("//:cli"),
            executable = True,
            cfg = "exec",
        ),
        "_cc_templates": attr.label(
            default = Label("//:interface_templates"),
        ),
        "_cc_visibility_template": attr.label(
            default = Label("//:resource/rosidl_generator_cpp__visibility_control.hpp.in"),
            allow_single_file = True,
        ),
        "_cc_deps": attr.label_list(
            default = [
                Label("@rosidl_runtime_cpp"),
            ],
            providers = [CcInfo],
        ),  
    },
    required_providers = [RosInterfaceInfo],
    required_aspect_providers = [
        [RosIdlInfo],
        [RosTypeDescriptionInfo],
        [CcInfo],
    ],
    provides = [RosCcBindingsInfo],
)
