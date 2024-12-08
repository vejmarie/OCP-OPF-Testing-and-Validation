# OCP-OPF-Testing-and-Validation

OPF Testing and Validation is a collection of test suites which can be used to validate correct behavior of freshly provisionned systems running OPF stack. The tests are based on work performed within the Testing and Validation OCP workgroup.

Initial implementation creates a bootable USB stick which is presented to a host either through a physical device or a virtual USB hub provided through the BMC to a host. The USB stick is automatically bootable (UEFI boot order must be adapted to support it) in UEFI mode and will automatically boot a linux image in read only mode, and execute the tests. Tests results aren't currently gathered outside the running O/S and system behavior must be monitored through the BMC.

# Supported architectures

Currently supported architectures are:
  - x86_64 (64 bits x86)
  - aarch64 (Tested on Ampere Altra processors) needs a specific qemu version to build

aarch64 is not yet activated

# Build instruction

Execute the ./build.sh script within a linux machine. The user running the script must be into a sudoer group as the script is extensively using file system creations tools and must have access to the mount command. Loop devices must be supported on the build machine. It is recommended to use an ephemeral build environment on a sandbox build system as this script is running command which could potentially hurt your machine if something wrong happens.
deboostrap is used as to create an initial rootfs from an ubuntu jammy distribution.

# Current known limitations

Actually only AMD64 support is enabled

# TODO

- Taking care of systems which are configured with an O/S first error reporting. In such cases hardware errors during test execution won't be retrieved and only system crash can be monitored
- Enhance tests numbers and validate test configuration
- Create an API between the BMC and the running O/S to retrieve test output for later analysis
