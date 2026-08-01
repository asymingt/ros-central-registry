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

load(":ament_index.bzl", _ament_index = "ament_index")
load(":ament_package.bzl", _ament_package = "ament_package")
load(":ament_resource.bzl", _register_ament_files = "register_ament_files", _register_ament_resource = "register_ament_resource")

ament_index = _ament_index
ament_package = _ament_package
register_ament_resource = _register_ament_resource
register_ament_files = _register_ament_files
