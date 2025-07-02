# Overview

This folder contains tooling for transforming a colcon workspace to a Bazel registry of ROS 2 packages, which is called the "ROS Central Registry" and is hosted at https://rcr.ros2.org. If all you need to do is create a new ROS 2 Bazel project then just add the following lines to your `.bazelrc` file:

```
# .bazelrc
common --registry=https://rcr.ros2.org
common --registry=https://bcr.bazel.build
```

Then you can then simply reference the ROS 2 distribution in your project module:

```
# MODULE.bazel
bazel_dep(name = "ros", version = "kilted-2025-05-23")

ros = use_extension("@ros//ros:extensions.bzl", "ros")
ros.load_packages("core")  # loads rclcpp, std_msgs, etc. 
```

And your code will magically know about ROS packages in the core distribution, so you can do this:

```
# BUILD.bazel
load("@rules_cc//cc:defs.bzl", "cc_binary")

cc_binary(
    name = "example_node",
    srcs = ["src/example.cc"],
    deps = [
        "@roscpp",
        "@std_msgs"
    ]
)
```

# Under the hood

All packages offered by the core libraries of ROS 2 use one of two build systems - setup.py and cmake. This project analyzes the source and build artifacts produced by these build systems within a ROS 2 workspace to transform the build rules into Bazel rules. In this architecture every ROS 2 package in the core library has a corresponding Bazel module in the ROS Central Registry, and each module builds everything it needs from source.

If you are familiar with previous Bazel / ROS 2 integrations, this approach is a little like drake-ros in the sense that it parses cmake API queries to auto-generate target information. However, instead of assuming that we're working off a pre-built ROS 2 workspace our approach does goes deeper to map targets back to their input source files, allowing CI to update Bazel files as needed. Our approach to transforming message IDLs to language bindings borrows heavily from mvukov's set of excellent Bazel rules. However, we go extend this approach to allow languages to be dynamically register themselves.

In summary, we have a CI plan that responds to updates to ROS 2 core packages to transforms any change to a package to an updated set of Bazel rules. These rules allow you to easily include one or more packages from ROS 2 in a pure Bazel environment, providing a hermetic build of the entire dependency tree from source. One can control the messaging middleware and other ROS 2 settings by specifying `--action_env` parameters.

# How this project is organized

```
+ development            workspace used to store artifacts generated as part of the
  + action_msgs
    + cache              source tarballs are downloaded and cached here
    + patches            patches to apply to bare source tree to obtain the desired result
    + workspace          git workspace for each ROS package           
  ...
+ examples               example projects (look at these if you want to get started)
  ...
+ modules                module releases for all ROS packages
  + action_msgs          module for a ROS package
    + 2.4.0              version of the module
      + patches          patches to the source repo to be buildable in Bazel   
      + overlay          files to overlay to support a Bazel build  
        + BUILD.bazel    information about how to build the ROS package  
        + MODULE.bazel   information about what other modules this ROS packages needs
      ...
    + metadata.json      information about module versions
  ...
+ tools                  tools to help with developer productivity
```

# Regenerating or updating the registry modules for ROS 2

The first step is to bootstrap the workspace, supplying a commit hash for the [rosdistro](https://github.com/ros/rosdistro) repo. Under the hood this is a shell script that calls `rosinstall_generator` to generate a `ros2.repos` file containing all packages in the distribution. It then checks out all repos and calls `colcon build --cmake-args --no-warn-unused-cli --graphviz=deps.dot -DBUILD_TESTING=OFF` to build the ROS workspace with cmake.

Install prerequisite tooling:

```
sudo apt install python3-rosinstall-generator ros-dev-tools
```

Bootstrap a ROS 2 workspace with the core library set:

```sh
mkdir -p workspace/src
pushd workspace
rosinstall_generator ros_core --rosdistro rolling --deps --format repos  > ros2.repos
vcs import -w 1 --input ros2.repos src
rosdep install --from-paths src --ignore-src -y --skip-keys "fastcdr rti-connext-dds-7.3.0 urdfdom_headers"
colcon build --cmake-args --no-warn-unused-cli --graphviz=deps.dot -DBUILD_TESTING=OFF
popd
```

Extract the package information for each package. This scrapes the source and build directories to extract information about how targets are built, and how targets and data are installed to the target install directory. It also keeps track of the original package location. 

```sh
python3 tools/semantics_from_workspace.py \
    -s workspace/src \
    -b workspace/build \
    -o workspace/info_targets.yaml
```

```sh
python3 tools/bazel_from_semantics.py \
    -t workspace/info_targets.yaml \
    -p workspace/info_patches.yaml \
    -o workspace/.yaml
```


Transform the target information to

```
bazel run //tools/extract_bazel
```


```
version: 1
packages:
    action_msgs:
        version: 2.4.0-1
        source: src/ros2/rcl_interfaces/action_msgs
        interfaces:
            messages:
                - msg/GoalInfo.msg
                - msg/GoalStatus.msg
                - msg/GoalStatusArray.msg
            srvs:
                - srv/CancelGoal.srv
            actions: []
            dependencies:
            - unique_identifier_msgs
    rclcpp:
        version: 29.6.1-1
        source: src/ros2/rclcpp/rclcpp
        targets:
            rclcpp:
                headers:
            linker:
        install:
            include: include






        
``` 