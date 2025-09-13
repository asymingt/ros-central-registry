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
load("@rules_cc//cc:defs.bzl", "CcInfo", "cc_common")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain")
load("//:types.bzl", "RosIdlInfo")

def _get_stem(path):
    return path.basename[:-len(path.extension) - 1]

def idl_tuple_from_path(path):
    idl_parts = path.split("/")
    return "/".join(idl_parts[:-2]) + ":" + idl_parts[-2] + "/" + idl_parts[-1]

def type_description_tuple_from_path(path):
    idl_parts = path.split("/")
    idl_type = idl_parts[-2]
    idl_name = idl_parts[-1].replace(".json", ".idl")
    return "{}/{}:".format(idl_type, idl_name) + path

def generate_sources(
    target,
    ctx,
    executable,
    mnemonic,
    input_idls,
    input_type_descriptions,
    input_templates,
    templates_hdrs,
    templates_srcs,
    template_visibility_control = None,
    additional = [],
    message_is_pascal_case = True
):
    # Extract message metadata from the IdlInfo provider, where it was calculated.
    package_name = target[RosIdlInfo].package_name
    message_type = target[RosIdlInfo].interface_type
    message_name = target[RosIdlInfo].interface_name
    message_code = target[RosIdlInfo].interface_code

    # Some message generation retains the message case.
    if not message_is_pascal_case:
        message_code = message_name

    # The first output file is the JSON file used as args to the generator.
    input_args = ctx.actions.declare_file(
        "{}/{}_{}_{}.json".format(package_name, message_type, message_name, mnemonic))

    # Prepare hdrs and srcs lists for output.
    output_hdrs = [
        ctx.actions.declare_file(
            "{}/{}/{}".format(package_name, message_type, t.format(message_code))
        ) for t in templates_hdrs
    ]
    output_srcs = [
        ctx.actions.declare_file(
            "{}/{}/{}".format(package_name, message_type, t.format(message_code))
        ) for t in templates_srcs
    ]

    # Write the generator query
    ctx.actions.write(
        input_args,
        json.encode(
            struct(
                package_name = package_name,
                idl_tuples = [idl_tuple_from_path(idl.path) for idl in input_idls],
                output_dir = input_args.dirname,
                template_dir = input_templates[0].dirname,
                type_description_tuples = [type_description_tuple_from_path(idl.path)
                    for idl in input_type_descriptions],
                target_dependencies = [],
            )
        )
    )

    # Pass the query through the generator
    ctx.actions.run_shell(
        command = "{exec} {genfile} {extra} {out}".format(
            exec = executable.path,
            genfile = "--generator-arguments-file={}".format(input_args.path),
            extra = " ".join(additional),
            out = "> /dev/null 2>&1"
        ),
        tools = [executable],
        inputs = input_idls + input_type_descriptions + input_templates + [input_args],
        outputs = output_hdrs + output_srcs,
        mnemonic = mnemonic,
        progress_message = "Running {} for {}".format(mnemonic, ctx.label.name),
    )

    # Optionally include 
    if template_visibility_control:
        output_c_visibility_control_stem = _get_stem(template_visibility_control)
        output_c_visibility_control_h = ctx.actions.declare_file(
            "{}/msg/{}".format(package_name, output_c_visibility_control_stem)
        )
        ctx.actions.expand_template(
            template = template_visibility_control,
            output = output_c_visibility_control_h,
            substitutions = {
                "@PROJECT_NAME@": package_name,
                "@PROJECT_NAME_UPPER@": package_name.upper(),
            },
        )
        output_hdrs.append(output_c_visibility_control_h)

    # Return the headers and sources
    return output_hdrs, output_srcs, _get_parent_dir(input_args.dirname)

def _get_parent_dir(path):
    return "/".join(path.split("/")[:-1])

# Merge headers, sources and deps into a CcInfo provider.
def generate_cc_info(ctx, name, hdrs, srcs, include_dirs = [], deps = []):

    # Query for the current CC toolchain and feature set.
    cc_toolchain = find_cc_toolchain(ctx)

    # Get the compiler feature configuration.
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    # Get a compilation context.
    (compilation_context, compilation_outputs) = cc_common.compile(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        srcs = srcs,
        public_hdrs = hdrs,
        compilation_contexts = [dep.compilation_context for dep in deps],
        name = name,
        includes = include_dirs,
    )

    # Get a linking context.
    if srcs:
        linking_context, _ = cc_common.create_linking_context_from_compilation_outputs(
            actions = ctx.actions,
            feature_configuration = feature_configuration,
            cc_toolchain = cc_toolchain,
            compilation_outputs = compilation_outputs,
            linking_contexts = [dep.linking_context for dep in deps],
            name = name,
            alwayslink = True,
        )
    else:
        linking_context = cc_common.merge_linking_contexts(
            linking_contexts = [dep.linking_context for dep in deps]
        )

    # Assemble and return the CcInfo object.
    cc_info = CcInfo(
        compilation_context = compilation_context,
        linking_context = linking_context,
    )
    return cc_info
    