
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

load("@rules_cc//cc:defs.bzl", "CcInfo", "cc_common")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rosidl_cmake//:types.bzl", "RosInterfaceInfo")
load("@rosidl_adapter//:types.bzl", "RosIdlInfo")
load("@rosidl_adapter//:tools.bzl", "generate_sources", "generate_cc_info")
load("@rosidl_generator_c//:types.bzl", "RosCBindingsInfo")
load("@rosidl_generator_cpp//:types.bzl", "RosCcBindingsInfo")
load("@rosidl_generator_type_description//:types.bzl", "RosTypeDescriptionInfo")
load(":types.bzl", "RosCTypesupportInfo")

def _c_typesupport_aspect_impl(target, ctx):
    input_idls = target[RosIdlInfo].idls.to_list()
    input_type_descriptions = target[RosTypeDescriptionInfo].jsons.to_list()

    # Generate type support
    c_typesupport_hdrs, c_typesupport_srcs, c_include_dir = generate_sources(
        target = target,
        ctx = ctx,
        executable = ctx.executable._c_typesupport_generator,
        mnemonic = "CTypeSupportGeneration",
        input_idls = input_idls,
        input_type_descriptions = input_type_descriptions,
        input_templates = ctx.attr._c_typesupport_templates[DefaultInfo].files.to_list(),
        templates_hdrs = [],
        templates_srcs = ["detail/{}__rosidl_typesupport_c.cpp"],
        additional = [
            "--typesupports",
            "rosidl_typesupport_introspection_c",
            "rosidl_typesupport_fastrtps_c",
            "rosidl_typesupport_protobuf_c",
        ],
    )

    # Generate the type support library for introspection
    c_introspection_hdrs, c_introspection_srcs, c_introspection_include_dir = generate_sources(
        target = target,
        ctx = ctx,
        executable = ctx.executable._c_typesupport_introspection_generator,
        mnemonic = "CTypeSupportIntrospectionGeneration",
        input_idls = input_idls,
        input_type_descriptions = input_type_descriptions,
        input_templates = ctx.attr._c_typesupport_introspection_templates[DefaultInfo].files.to_list(),
        templates_hdrs = ["detail/{}__rosidl_typesupport_introspection_c.h"],
        templates_srcs = ["detail/{}__rosidl_typesupport_introspection_c.c"],
        template_visibility_control = ctx.file._c_typesupport_introspection_visibility_template,
    )

    # Generate the type support library for fastrtps
    c_fastrtps_hdrs, c_fastrtps_srcs, c_fastrtps_include_dir = generate_sources(
        target = target,
        ctx = ctx,
        executable = ctx.executable._c_typesupport_fastrtps_generator,
        mnemonic = "CTypeSupportFastRTPSGeneration",
        input_idls = input_idls,
        input_type_descriptions = input_type_descriptions,
        input_templates = ctx.attr._c_typesupport_fastrtps_templates[DefaultInfo].files.to_list(),
        templates_hdrs = ["detail/{}__rosidl_typesupport_fastrtps_c.h"],
        templates_srcs = ["detail/{}__rosidl_typesupport_fastrtps_c.cpp"],
        template_visibility_control = ctx.file._c_typesupport_fastrtps_visibility_template,
    )

    # TODO(asymingt) protobuf_c typesupport symbols conflict with the protobuf_cpp symbols.
    # I doubt however that anybody will realistically try to use these. We can always explore
    # enabling them if somebody has a need for them.
    # c_protobuf_hdrs, c_protobuf_srcs, c_protobuf_include_dir = generate_sources(
    #     target = target,
    #     ctx = ctx,
    #     executable = ctx.executable._c_typesupport_protobuf_generator,
    #     mnemonic = "CTypeSupportProtobufGeneration",
    #     input_idls = input_idls,
    #     input_type_descriptions = input_type_descriptions,
    #     input_templates = ctx.attr._c_typesupport_protobuf_templates[DefaultInfo].files.to_list(),
    #     templates_hdrs = ["{}__rosidl_typesupport_protobuf_c.hpp"],
    #     templates_srcs = ["{}__rosidl_typesupport_protobuf_c.cpp"],
    #     template_visibility_control = ctx.file._c_typesupport_protobuf_visibility_template,
    # )

    # These deps will all have CcInfo providers.
    deps = [target[CcInfo]]
    deps.extend([dep[CcInfo] for dep in ctx.attr._c_deps + ctx.rule.attr.deps if CcInfo in dep])
    deps.extend([d for d in target[RosCBindingsInfo].cc_infos.to_list()])
    deps.extend([d for d in target[RosCcBindingsInfo].cc_infos.to_list()])
    for dep in ctx.rule.attr.deps:
        if RosCTypesupportInfo in dep:
            deps.extend([d for d in dep[RosCTypesupportInfo].cc_infos.to_list()])
    
    # Merge headers, sources and deps into a CcInfo provider.
    hdrs = c_typesupport_hdrs + c_introspection_hdrs + c_fastrtps_hdrs
    srcs = c_typesupport_srcs + c_introspection_srcs + c_fastrtps_srcs
    cc_info = generate_cc_info(
        ctx = ctx,
        name = "{}_c_typesupport".format(ctx.label.name),
        hdrs = hdrs,
        srcs = srcs,
        deps = deps,
        include_dirs = [
            c_include_dir,
            c_introspection_include_dir,
            c_fastrtps_include_dir,
        ]
    )

    # Return a CcInfo provider for the aspect.
    return [
        RosCTypesupportInfo(
            cc_infos = depset(
                direct = [cc_info],
                transitive = [
                    dep[RosCTypesupportInfo].cc_infos
                        for dep in ctx.rule.attr.deps if RosCTypesupportInfo in dep
                ],
            ),
            cc_files = depset(
                direct = hdrs + srcs,
                transitive = [
                    dep[RosCTypesupportInfo].cc_files
                        for dep in ctx.rule.attr.deps if RosCTypesupportInfo in dep
                ],
            ),
        )
    ]

c_typesupport_aspect = aspect(
    implementation = _c_typesupport_aspect_impl,
    toolchains = use_cc_toolchain(),
    attr_aspects = ["deps"],
    fragments = ["cpp"],
    attrs = {
        #########################################################################
        # General type support generation #######################################
        #########################################################################
        
        "_c_typesupport_generator": attr.label(
            default = Label("@rosidl_typesupport_c//:cli"),
            executable = True,
            cfg = "exec",
        ),
        "_c_typesupport_templates": attr.label(
            default = Label("@rosidl_typesupport_c//:interface_templates"),
        ),

        #########################################################################
        # Introspection type support generation #################################
        #########################################################################
        
        "_c_typesupport_introspection_generator": attr.label(
            default = Label("@rosidl_typesupport_introspection_c//:cli"),
            executable = True,
            cfg = "exec",
        ),
        "_c_typesupport_introspection_templates": attr.label(
            default = Label("@rosidl_typesupport_introspection_c//:interface_templates"),
        ),
        "_c_typesupport_introspection_visibility_template": attr.label(
            default = Label("@rosidl_typesupport_introspection_c//:resource/rosidl_typesupport_introspection_c__visibility_control.h.in"),
            allow_single_file = True,
        ),

        #########################################################################
        # FastRTPS type support generation ######################################
        #########################################################################
        
        "_c_typesupport_fastrtps_generator": attr.label(
            default = Label("@rosidl_typesupport_fastrtps_c//:cli"),
            executable = True,
            cfg = "exec",
        ),
        "_c_typesupport_fastrtps_templates": attr.label(
            default = Label("@rosidl_typesupport_fastrtps_c//:interface_templates"),
        ),
        "_c_typesupport_fastrtps_visibility_template": attr.label(
            default = Label("@rosidl_typesupport_fastrtps_c//:resource/rosidl_typesupport_fastrtps_c__visibility_control.h.in"),
            allow_single_file = True,
        ),

        #########################################################################
        # Protobuf type support generation ######################################
        #########################################################################
        
        "_c_typesupport_protobuf_generator": attr.label(
            default = Label("@rosidl_typesupport_protobuf_c//:cli"),
            executable = True,
            cfg = "exec",
        ),
        "_c_typesupport_protobuf_templates": attr.label(
            default = Label("@rosidl_typesupport_protobuf_c//:interface_templates"),
        ),
        "_c_typesupport_protobuf_visibility_template": attr.label(
            default = Label("@rosidl_typesupport_protobuf_c//:resource/rosidl_typesupport_protobuf_c__visibility_control.h.in"),
            allow_single_file = True,
        ),

        #########################################################################
        # Dependencies ##########################################################
        #########################################################################
        
        "_c_deps": attr.label_list(
            default = [
                Label("@rosidl_typesupport_interface"),
                Label("@rosidl_typesupport_c"),
                Label("@rosidl_typesupport_introspection_c"),
                Label("@rosidl_typesupport_fastrtps_c"),
                Label("@rosidl_typesupport_protobuf_c"),
                Label("@rmw"),
            ],
            providers = [CcInfo],
        ),
        
    },
    required_providers = [RosInterfaceInfo],
    required_aspect_providers = [
        [RosIdlInfo],
        [RosTypeDescriptionInfo],
        [CcInfo],
        [RosCBindingsInfo],
        [RosCcBindingsInfo]
    ],
    provides = [RosCTypesupportInfo],
)
