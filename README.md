# ROS Central Registry

This is a fork of the [Bazel Central Registry](https://github.com/bazelbuild/bazel-central-registry) (BCR) for use by the [Robot Operating System](https://ros.org) project. It retains the build system and tooling, but switches out the set of modules and CI plans to be ROS-specific.

We intend to keep most of the directory structure in place to help with iteration. Our broad objective is to push any system-level dependencies upstream to the BCR, but keep ROS-level dependencies in this repository.

If you are looking to work with ROS in Bazel, please see [the example project](https://github.com/asymingt/rcr-examples)