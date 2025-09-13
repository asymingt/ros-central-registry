
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

load("@protobuf//bazel/common:proto_common.bzl", "proto_common")
load("@protobuf//bazel/private:cc_proto_support.bzl", "cc_proto_compile_and_link")
load("@rules_cc//cc:find_cc_toolchain.bzl", "use_cc_toolchain")
load("@rosidl_cmake//:types.bzl", "RosInterfaceInfo")
load("@rosidl_adapter//:types.bzl", "RosIdlInfo")
load("@rosidl_adapter//:tools.bzl", "generate_sources")
load(":types.bzl", "RosProtoInfo")
load(":tools.bzl", "merge_proto_infos")

def _proto_aspect_impl(target, ctx):
    # Extract message metadata from the IdlInfo provider, where it was calculated.
    package_name = target[RosIdlInfo].package_name
    message_type = target[RosIdlInfo].interface_type
    message_name = target[RosIdlInfo].interface_name
    message_code = target[RosIdlInfo].interface_code

    # Generate the .proto file for the current mode.
    hdrs, srcs, proto_include_dir = generate_sources(
        target = target,
        ctx = ctx,
        executable = ctx.executable._proto_generator,
        mnemonic = "IdlToProtobuf",
        input_idls = target[RosIdlInfo].idls.to_list(),
        input_type_descriptions = [],
        input_templates = ctx.attr._proto_templates[DefaultInfo].files.to_list(),
        templates_hdrs = [],
        templates_srcs = ["{}.proto"],
        template_visibility_control = ctx.file._proto_visibility_template,
        message_is_pascal_case = False,
    )

    # Generate a flattened ProtoInfo for this specific target. Note that the collected
    # .proto files will be symlinked into a virtual workspace named by this target.
    proto_info, proto_path = merge_proto_infos(
        ctx = ctx,
        name = target.label.name,
        srcs = srcs,
        deps = ctx.rule.attr.deps,
    )

    # The files that are produced by the proto compiler will end up relative to the
    # proto_path specified in the proto_info. So, let's expect them there...
    output_proto_h = ctx.actions.declare_file(
        "{}/{}/{}/{}.pb.h".format(proto_path, package_name, message_type, message_name))
    output_proto_cc = ctx.actions.declare_file(
        "{}/{}/{}/{}.pb.cc".format(proto_path, package_name, message_type, message_name))

    # Create the C++ interface for this specific proto. You might think that doing this
    # here is a bit strange, because if this target exports a ProtoInfo, then any rule
    # requiring C++ bindings should be able to tack on cc_proto_aspect from @protobuf
    # to get these generated. However, for some reason this does not work. So, since we
    # have an active protobuf import, we'll replicate what cc_proto_aspect does...
    proto_toolchain = ctx.toolchains["@protobuf//bazel/private:cc_toolchain_type"].proto
    proto_common.compile(
        actions = ctx.actions,
        proto_info = proto_info,
        proto_lang_toolchain_info = proto_toolchain,
        generated_files = [output_proto_h, output_proto_cc],
        experimental_output_files = "multiple",
    )
    deps = []
    if proto_toolchain.runtime:
        deps = [proto_toolchain.runtime]
    deps.extend(getattr(ctx.rule.attr, "deps", []))
    cc_info, libraries, temps = cc_proto_compile_and_link(
        ctx = ctx,
        deps = deps,
        sources = [output_proto_cc],
        headers = [output_proto_h],
        textual_hdrs = hdrs,
        strip_include_prefix = proto_path,
    )

    # Collect all of the sources from the dependencies.
    return [
        RosProtoInfo(
            protos = depset(
                direct = srcs,
                transitive = [
                    dep[RosProtoInfo].protos
                        for dep in ctx.rule.attr.deps if RosProtoInfo in dep
                ],
            ),
        ),
        proto_info,
        cc_info
    ]


proto_aspect = aspect(
    implementation = _proto_aspect_impl,
    attr_aspects = ["deps"],
    fragments = ["proto", "cpp"],
    toolchains = use_cc_toolchain() + [
        "@protobuf//bazel/private:proto_toolchain_type",
        "@protobuf//bazel/private:cc_toolchain_type",
    ],
    attrs = {
        "_proto_generator": attr.label(
            default = Label("//:cli"),
            executable = True,
            cfg = "exec",
        ),
        "_proto_templates": attr.label(
            default = Label("//:interface_templates"),
        ),
        "_proto_visibility_template": attr.label(
            default = Label("//:resource/rosidl_adapter_proto__visibility_control.h.in"),
            allow_single_file = True,
        ),
    },
    required_providers = [RosInterfaceInfo],
    required_aspect_providers = [RosIdlInfo],
    provides = [RosProtoInfo, ProtoInfo, CcInfo],
)

