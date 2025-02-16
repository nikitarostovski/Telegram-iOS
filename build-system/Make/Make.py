#!/bin/python3

import argparse
import os
import shlex
import sys
import tempfile

from BuildEnvironment import is_apple_silicon, resolve_executable, call_executable, BuildEnvironment
from ProjectGeneration import generate


class BazelCommandLine:
    def __init__(self, bazel_path, bazel_x86_64_path, override_bazel_version, override_xcode_version):
        self.build_environment = BuildEnvironment(
            base_path=os.getcwd(),
            bazel_path=bazel_path,
            bazel_x86_64_path=bazel_x86_64_path,
            override_bazel_version=override_bazel_version,
            override_xcode_version=override_xcode_version
        )
        self.remote_cache = None
        self.cache_dir = None
        self.additional_args = None
        self.build_number = None
        self.configuration_args = None
        self.configuration_path = None

        self.common_args = [
            # https://docs.bazel.build/versions/master/command-line-reference.html
            # Ask bazel to print the actual resolved command line options.
            '--announce_rc',

            # https://github.com/bazelbuild/rules_swift
            # If enabled, Swift compilation actions will use the same global Clang module
            # cache used by Objective-C compilation actions. This is disabled by default
            # because under some circumstances Clang module cache corruption can cause the
            # Swift compiler to crash (sometimes when switching configurations or syncing a
            # repository), but disabling it also causes a noticeable build time regression
            # so it can be explicitly re-enabled by users who are not affected by those
            # crashes.
            '--features=swift.use_global_module_cache',

            # https://docs.bazel.build/versions/master/command-line-reference.html
            # Print the subcommand details in case of failure.
            '--verbose_failures',
        ]

        self.common_build_args = [
            # https://github.com/bazelbuild/rules_swift
            # If enabled and whole module optimisation is being used, the `*.swiftdoc`,
            # `*.swiftmodule` and `*-Swift.h` are generated with a separate action
            # rather than as part of the compilation.
            '--features=swift.split_derived_files_generation',

            # https://github.com/bazelbuild/rules_swift
            # If enabled the skip function bodies frontend flag is passed when using derived
            # files generation.
            '--features=swift.skip_function_bodies_for_derived_files',
            
            # Set the number of parallel processes to match the available CPU core count.
            '--jobs={}'.format(os.cpu_count()),
        ]

        self.common_debug_args = [
            # https://github.com/bazelbuild/rules_swift
            # If enabled, Swift compilation actions will use batch mode by passing
            # `-enable-batch-mode` to `swiftc`. This is a new compilation mode as of
            # Swift 4.2 that is intended to speed up non-incremental non-WMO builds by
            # invoking a smaller number of frontend processes and passing them batches of
            # source files.
            '--features=swift.enable_batch_mode',

            # https://docs.bazel.build/versions/master/command-line-reference.html
            # Set the number of parallel jobs per module to saturate the available CPU resources.
            '--swiftcopt=-j{}'.format(os.cpu_count() - 1),
        ]

        self.common_release_args = [
            # https://github.com/bazelbuild/rules_swift
            # Enable whole module optimization.
            '--features=swift.opt_uses_wmo',

            # https://github.com/bazelbuild/rules_swift
            # Use -Osize instead of -O when building swift modules.
            '--features=swift.opt_uses_osize',

            # --num-threads 0 forces swiftc to generate one object file per module; it:
            # 1. resolves issues with the linker caused by the swift-objc mixing.
            # 2. makes the resulting binaries significantly smaller (up to 9% for this project).
            '--swiftcopt=-num-threads', '--swiftcopt=0',

            # Strip unsused code.
            '--features=dead_strip',
            '--objc_enable_binary_stripping',

            # Always embed bitcode into Watch binaries. This is required by the App Store.
            '--apple_bitcode=watchos=embedded',
        ]

    def add_remote_cache(self, host):
        self.remote_cache = host

    def add_cache_dir(self, path):
        self.cache_dir = path

    def add_additional_args(self, additional_args):
        self.additional_args = additional_args

    def set_build_number(self, build_number):
        self.build_number = build_number

    def set_configuration_path(self, path):
        self.configuration_path = path

    def set_configuration(self, configuration):
        if configuration == 'debug_arm64':
            self.configuration_args = [
                # bazel debug build configuration
                '-c', 'dbg',

                # Build single-architecture binaries. It is almost 2 times faster is 32-bit support is not required.
                '--ios_multi_cpus=arm64',

                # Always build universal Watch binaries.
                '--watchos_cpus=armv7k,arm64_32'
            ] + self.common_debug_args
        elif configuration == 'release_arm64':
            self.configuration_args = [
                # bazel optimized build configuration
                '-c', 'opt',

                # Build single-architecture binaries. It is almost 2 times faster is 32-bit support is not required.
                '--ios_multi_cpus=arm64',

                # Always build universal Watch binaries.
                '--watchos_cpus=armv7k,arm64_32'
            ] + self.common_release_args
        elif configuration == 'release_universal':
            self.configuration_args = [
                # bazel optimized build configuration
                '-c', 'opt',

                # Build universal binaries.
                '--ios_multi_cpus=armv7,arm64',

                # Always build universal Watch binaries.
                '--watchos_cpus=armv7k,arm64_32',
                
                # Generate DSYM files when building.
                '--apple_generate_dsym',

                # Require DSYM files as build output.
                '--output_groups=+dsyms'
            ] + self.common_release_args
        else:
            raise Exception('Unknown configuration {}'.format(configuration))

    def invoke_clean(self):
        combined_arguments = [
            self.build_environment.bazel_path,
            'clean',
            '--expunge'
        ]

        print('TelegramBuild: running {}'.format(combined_arguments))
        call_executable(combined_arguments)

    def get_define_arguments(self):
        return [
            '--define=buildNumber={}'.format(self.build_number),
            '--define=telegramVersion={}'.format(self.build_environment.app_version)
        ]

    def get_project_generation_arguments(self):
        combined_arguments = []
        combined_arguments += self.common_args
        combined_arguments += self.common_debug_args
        combined_arguments += self.get_define_arguments()

        if self.remote_cache is not None:
            combined_arguments += [
                '--remote_cache={}'.format(self.remote_cache),
                '--experimental_remote_downloader="{}"'.format(self.remote_cache)
            ]
        elif self.cache_dir is not None:
            combined_arguments += [
                '--disk_cache={path}'.format(path=self.cache_dir)
            ]

        return combined_arguments

    def invoke_build(self):
        combined_arguments = [
            self.build_environment.bazel_path,
            'build',
            'Telegram/Telegram'
        ]

        if self.configuration_path is None:
            raise Exception('configuration_path is not defined')

        combined_arguments += [
            '--override_repository=build_configuration={}'.format(self.configuration_path)
        ]

        combined_arguments += self.common_args
        combined_arguments += self.common_build_args
        combined_arguments += self.get_define_arguments()

        if self.remote_cache is not None:
            combined_arguments += [
                '--remote_cache={}'.format(self.remote_cache),
                '--experimental_remote_downloader="{}"'.format(self.remote_cache)
            ]
        elif self.cache_dir is not None:
            combined_arguments += [
                '--disk_cache={path}'.format(path=self.cache_dir)
            ]

        combined_arguments += self.configuration_args

        print('TelegramBuild: running {}'.format(combined_arguments))
        call_executable(combined_arguments)


def clean(arguments):
    bazel_command_line = BazelCommandLine(
        bazel_path=arguments.bazel,
        bazel_x86_64_path=None,
        override_bazel_version=arguments.overrideBazelVersion,
        override_xcode_version=arguments.overrideXcodeVersion
    )

    bazel_command_line.invoke_clean()


def resolve_configuration(bazel_command_line: BazelCommandLine, arguments):
    if arguments.configurationGenerator is not None:
        configuration_generator_arguments = shlex.split(arguments.configurationGenerator)

        configuration_generator_executable = resolve_executable(configuration_generator_arguments[0])

        if configuration_generator_executable is None:
            print('{} is not a valid executable'.format(configuration_generator_arguments[0]))
            exit(1)

        temp_configuration_path = tempfile.mkdtemp()

        resolved_configuration_generator_arguments = [configuration_generator_executable]
        resolved_configuration_generator_arguments += configuration_generator_arguments[1:]
        resolved_configuration_generator_arguments += [temp_configuration_path]

        call_executable(resolved_configuration_generator_arguments, use_clean_environment=False)

        print('TelegramBuild: using generated configuration in {}'.format(temp_configuration_path))
        bazel_command_line.set_configuration_path(temp_configuration_path)
    elif arguments.configurationPath is not None:
        absolute_configuration_path = os.path.abspath(arguments.configurationPath)
        if not os.path.isdir(absolute_configuration_path):
            print('Error: {} does not exist'.format(absolute_configuration_path))
            exit(1)
        bazel_command_line.set_configuration_path(absolute_configuration_path)
    else:
        raise Exception('Neither configurationPath nor configurationGenerator are set')


def generate_project(arguments):
    bazel_x86_64_path = None
    if is_apple_silicon():
        bazel_x86_64_path = arguments.bazel_x86_64
            
    bazel_command_line = BazelCommandLine(
        bazel_path=arguments.bazel,
        bazel_x86_64_path=bazel_x86_64_path,
        override_bazel_version=arguments.overrideBazelVersion,
        override_xcode_version=arguments.overrideXcodeVersion
    )

    if arguments.cacheDir is not None:
        bazel_command_line.add_cache_dir(arguments.cacheDir)
    elif arguments.cacheHost is not None:
        bazel_command_line.add_remote_cache(arguments.cacheDir)

    resolve_configuration(bazel_command_line, arguments)

    bazel_command_line.set_build_number(arguments.buildNumber)

    disable_extensions = False
    if arguments.disableExtensions is not None:
        disable_extensions = arguments.disableExtensions

    call_executable(['killall', 'Xcode'], check_result=False)

    generate(
        build_environment=bazel_command_line.build_environment,
        disable_extensions=disable_extensions,
        configuration_path=bazel_command_line.configuration_path,
        bazel_app_arguments=bazel_command_line.get_project_generation_arguments()
    )


def build(arguments):
    bazel_command_line = BazelCommandLine(
        bazel_path=arguments.bazel,
        bazel_x86_64_path=None,
        override_bazel_version=arguments.overrideBazelVersion,
        override_xcode_version=arguments.overrideXcodeVersion
    )

    if arguments.cacheDir is not None:
        bazel_command_line.add_cache_dir(arguments.cacheDir)
    elif arguments.cacheHost is not None:
        bazel_command_line.add_remote_cache(arguments.cacheDir)

    resolve_configuration(bazel_command_line, arguments)

    bazel_command_line.set_configuration(arguments.configuration)
    bazel_command_line.set_build_number(arguments.buildNumber)

    bazel_command_line.invoke_build()


def add_project_and_build_common_arguments(current_parser: argparse.ArgumentParser):
    group = current_parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        '--configurationPath',
        help='''
            Path to a folder containing build configuration and provisioning profiles.
            See build-system/example-configuration for an example.
            ''',
        metavar='path'
    )
    group.add_argument(
        '--configurationGenerator',
        help='''
            A command line invocation that will dynamically generate the configuration data
            (project constants and provisioning profiles).
            The expression will be parsed according to the shell parsing rules into program and arguments parts.
            The program will be then invoked with the given arguments plus the path to the output directory.   
            See build-system/generate-configuration.sh for an example.
            Example: --configurationGenerator="sh ~/my_script.sh argument1"
            ''',
        metavar='command'
    )


if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='Make')

    parser.add_argument(
        '--verbose',
        action='store_true',
        default=False,
        help='Print debug info'
    )

    parser.add_argument(
        '--bazel',
        required=True,
        help='Use custom bazel binary',
        metavar='path'
    )

    parser.add_argument(
        '--overrideBazelVersion',
        action='store_true',
        help='Override bazel version with the actual version reported by the bazel binary'
    )

    parser.add_argument(
        '--overrideXcodeVersion',
        action='store_true',
        help='Override xcode version with the actual version reported by \'xcode-select -p\''
    )

    parser.add_argument(
        '--bazelArguments',
        required=False,
        help='Add additional arguments to all bazel invocations.',
        metavar='arguments'
    )

    cacheTypeGroup = parser.add_mutually_exclusive_group()
    cacheTypeGroup.add_argument(
        '--cacheHost',
        required=False,
        help='Use remote build artifact cache to speed up rebuilds (See https://github.com/buchgr/bazel-remote).',
        metavar='http://host:9092'
    )
    cacheTypeGroup.add_argument(
        '--cacheDir',
        required=False,
        help='Cache build artifacts in a local directory to speed up rebuilds.',
        metavar='path'
    )

    subparsers = parser.add_subparsers(dest='commandName', help='Commands')

    cleanParser = subparsers.add_parser(
        'clean', help='''
            Clean local bazel cache. Does not affect files cached remotely (via --cacheHost=...) or 
            locally in an external directory ('--cacheDir=...')
            '''
    )

    generateProjectParser = subparsers.add_parser('generateProject', help='Generate Xcode project')
    if is_apple_silicon():
        generateProjectParser.add_argument(
            '--bazel_x86_64',
            required=True,
            help='A standalone bazel x86_64 binary is required to generate a project on Apple Silicon.',
            metavar='path'
        )
    generateProjectParser.add_argument(
        '--buildNumber',
        required=False,
        type=int,
        default=10000,
        help='Build number.',
        metavar='number'
    )
    add_project_and_build_common_arguments(generateProjectParser)
    generateProjectParser.add_argument(
        '--disableExtensions',
        action='store_true',
        default=False,
        help='''
            The generated project will not include app extensions.
            This allows Xcode to properly index the source code.
            '''
    )

    buildParser = subparsers.add_parser('build', help='Build the app')
    buildParser.add_argument(
        '--buildNumber',
        required=True,
        type=int,
        help='Build number.',
        metavar='number'
    )
    add_project_and_build_common_arguments(buildParser)
    buildParser.add_argument(
        '--configuration',
        choices=[
            'debug_arm64',
            'release_arm64',
            'release_universal'
        ],
        required=True,
        help='Build configuration'
    )

    if len(sys.argv) < 2:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()

    if args.verbose:
        print(args)

    if args.commandName is None:
        exit(0)

    try:
        if args.commandName == 'clean':
            clean(arguments=args)
        elif args.commandName == 'generateProject':
            generate_project(arguments=args)
        elif args.commandName == 'build':
            build(arguments=args)
        else:
            raise Exception('Unknown command')
    except KeyboardInterrupt:
        pass
