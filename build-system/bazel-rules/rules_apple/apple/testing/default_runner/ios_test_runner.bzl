# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""iOS test runner rule."""

load(
    "@build_bazel_rules_apple//apple/testing:apple_test_rules.bzl",
    "AppleTestRunnerInfo",
)

def _get_template_substitutions(*, device_type, os_version, simulator_creator, testrunner):
    """Returns the template substitutions for this runner."""
    subs = {
        "device_type": device_type,
        "os_version": os_version,
        "simulator_creator": simulator_creator,
        "testrunner_binary": testrunner,
    }
    return {"%(" + k + ")s": subs[k] for k in subs}

def _get_execution_environment(*, xcode_config):
    """Returns environment variables the test runner requires"""
    execution_environment = {}
    xcode_version = str(xcode_config.xcode_version())
    if xcode_version:
        execution_environment["XCODE_VERSION_OVERRIDE"] = xcode_version

    return execution_environment

def _ios_test_runner_impl(ctx):
    """Implementation for the ios_test_runner rule."""

    os_version = str(ctx.attr.os_version or ctx.fragments.objc.ios_simulator_version or "")
    device_type = ctx.attr.device_type or ctx.fragments.objc.ios_simulator_device or ""

    ctx.actions.expand_template(
        template = ctx.file._test_template,
        output = ctx.outputs.test_runner_template,
        substitutions = _get_template_substitutions(
            device_type = device_type,
            os_version = os_version,
            simulator_creator = ctx.executable._simulator_creator.short_path,
            testrunner = ctx.executable._testrunner.short_path,
        ),
    )
    return [
        AppleTestRunnerInfo(
            test_runner_template = ctx.outputs.test_runner_template,
            execution_requirements = ctx.attr.execution_requirements,
            execution_environment = _get_execution_environment(
                xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
            ),
            test_environment = ctx.attr.test_environment,
        ),
        DefaultInfo(
            runfiles = ctx.attr._simulator_creator[DefaultInfo].default_runfiles
                .merge(ctx.attr._testrunner[DefaultInfo].default_runfiles),
        ),
    ]

ios_test_runner = rule(
    _ios_test_runner_impl,
    attrs = {
        "device_type": attr.string(
            default = "",
            doc = """
The device type of the iOS simulator to run test. The supported types correspond
to the output of `xcrun simctl list devicetypes`. E.g., iPhone 6, iPad Air.
By default, it is the latest supported iPhone type.'
""",
        ),
        "execution_requirements": attr.string_dict(
            allow_empty = False,
            default = {"requires-darwin": ""},
            doc = """
Dictionary of strings to strings which specifies the execution requirements for
the runner. In most common cases, this should not be used.
""",
        ),
        "os_version": attr.string(
            default = "",
            doc = """
The os version of the iOS simulator to run test. The supported os versions
correspond to the output of `xcrun simctl list runtimes`. ' 'E.g., 11.2, 9.3.
By default, it is the latest supported version of the device type.'
""",
        ),
        "test_environment": attr.string_dict(
            doc = """
Optional dictionary with the environment variables that are to be propagated
into the XCTest invocation.
""",
        ),
        "_test_template": attr.label(
            default = Label(
                "@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.template.sh",
            ),
            allow_single_file = True,
        ),
        "_testrunner": attr.label(
            default = Label(
                "@xctestrunner//:ios_test_runner",
            ),
            executable = True,
            cfg = "exec",
            doc = """
It is the rule that needs to provide the AppleTestRunnerInfo provider. This
dependency is the test runner binary.
""",
        ),
        "_simulator_creator": attr.label(
            default = Label(
                "@build_bazel_rules_apple//apple/testing/default_runner:simulator_creator",
            ),
            executable = True,
            cfg = "exec",
        ),
        "_xcode_config": attr.label(
            default = configuration_field(
                fragment = "apple",
                name = "xcode_config_label",
            ),
        ),
    },
    outputs = {
        "test_runner_template": "%{name}.sh",
    },
    fragments = ["apple", "objc"],
    doc = """
Rule to identify an iOS runner that runs tests for iOS.

The runner will create a new simulator according to the given arguments to run
tests.

Outputs:
  AppleTestRunnerInfo:
    test_runner_template: Template file that contains the specific mechanism
        with which the tests will be performed.
    execution_requirements: Dictionary that represents the specific hardware
        requirements for this test.
  Runfiles:
    files: The files needed during runtime for the test to be performed.
""",
)
