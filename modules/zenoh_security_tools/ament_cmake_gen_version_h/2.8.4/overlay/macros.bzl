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

def generate_ros_version_defines():
    package_name = native.module_name()
    package_version = native.module_version()
    package_version_parts = package_version.split(".")
    package_version_major = package_version_parts[0] if len(package_version_parts) > 0 else ""
    package_version_minor = package_version_parts[1] if len(package_version_parts) > 1 else ""
    package_version_patch = package_version_parts[2] if len(package_version_parts) > 2 else ""
    return [
        "PROJECT_NAME_UPPER={}".format(package_name.upper()),
        "VERSION_MAJOR={}".format(package_version_major),
        "VERSION_MINOR={}".format(package_version_minor),
        "VERSION_PATCH={}".format(package_version_patch),
        "VERSION_STR={}".format(package_version),
    ]