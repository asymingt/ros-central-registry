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
load("@protobuf//bazel/common:proto_info.bzl", "ProtoInfo")
load("@protobuf//bazel/private:cc_proto_support.bzl", "cc_proto_compile_and_link")
load("@rules_cc//cc:find_cc_toolchain.bzl", "use_cc_toolchain")
load(":types.bzl", "RosProtoInfo")

def merge_proto_infos(ctx, name, deps, srcs = []):
    # Generating a ProtoInfo is not straightforward. There are some important limitations
    # that make it hard for an aspect to produce a ProtoInfo. You can see more info here:
    #
    #    https://github.com/protocolbuffers/protobuf/issues/23255
    #
    # So, as a compromise, what we will do is collect the dependency tree of .proto files
    # here and symlink them into a virtual directory, making them all direct sources to
    # a single ProtoInfo. This will allow a downstream consumer to use this target as a
    # dependency to `cc_proto_library` to generate bindings for another context.

    # Use the depset data structure to deduplicate the proto_infos from the whole dep tree.
    proto_files = depset(
        transitive = [
            dep[RosProtoInfo].protos for dep in deps if RosProtoInfo in dep
        ]
    ).to_list() + srcs

    # We are going to use a target-name prefixed workspace to avoid symlink collisions.
    # The name _virtual_imports/<target> is a specific structure that is supported by
    # the ProtoInfo constructor when using vertual sources!
    proto_path = "_virtual_imports/{}".format(name)

    # Create a new descriptor file for the ProtoInfo, which we'll compile on demand.
    descriptor_set = ctx.actions.declare_file("{}/{}".format(proto_path, "proto.bin"))

    # Symlink all protos into a common path to use as direct dependencies. This is a
    # requirement for the protobuf engine to function as expected.
    virtual_srcs = []
    for proto in proto_files:
        # A universal way of getting pkg_type_name = sensor_msgs/msg/Image.proto that
        # may work in other contexts, and not specifically for ROS protos.
        prefix = ""
        if proto.owner.workspace_root:
            prefix += proto.owner.workspace_root + "/"
        if proto.owner.package:
            prefix += proto.owner.package + "/"
        pkg_type_name = proto.short_path.replace("..", "external").removeprefix(prefix)

        # Now create a symlink at <proto_path>/sensor_msgs/msg/Image.proto that points
        # to the originally generated proto file from the other module.
        src = ctx.actions.declare_file("{}/{}".format(proto_path, pkg_type_name))
        ctx.actions.symlink(output = src, target_file = proto)
        virtual_srcs.append(src)

    # Construct the ProtoInfo to be returned. Note that at this point we have no deps. We
    # have effectively flattened the tree. This should be OK because cc_proto_library is
    # written to only accept one value in deps = [], so there is no chance of collision.
    proto_info = ProtoInfo(
        srcs = virtual_srcs,
        descriptor_set = descriptor_set, 
        workspace_root = ctx.label.workspace_root,
        proto_path = ctx.label.package + "/" + proto_path if ctx.label.package else proto_path, 
        bin_dir = ctx.bin_dir.path,
        deps = [],
    )
    
    # Create the descriptor for the proto_info. This is a binary blob capturing all the
    # tpy information contained in the proto collection. Ideally we'd have depsets of
    # this and protos in the aspect, and merge at each node. However, the cc_proto_aspect
    # does not seem to be called when we do this.
    proto_toolchain = ctx.toolchains["@protobuf//bazel/private:proto_toolchain_type"]
    proto_common.compile(
        actions = ctx.actions,
        proto_info = proto_info,
        proto_lang_toolchain_info = proto_toolchain.proto,
        generated_files = [descriptor_set],
    )

    # Return a flattened ProtoInfo with virtual sources. We also return the proto path
    # so that if we pass this proto_info to a proto compiler we know where the output
    # artifacts will end up being written.
    return proto_info, proto_path

