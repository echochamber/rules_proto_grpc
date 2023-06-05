#!/bin/bash

#
# Script is written to be run from the WORKSPACE root
#
set -eu
set -o pipefail
set -x

PROTOBUF_VERSION="3.21.9"
GRPC_VERSION="2.53.0"

OUTPUT_DIR="$(pwd)/csharp/nuget"
FILE_NAME="nuget.bzl"
DOTNET_TOOLCHAIN="$(uname -sm | tr 'A-Z ' 'a-z_' | sed -e 's/x86_64/amd64/')_6.0.101"
TOOL="bazel run --host_platform=@io_bazel_rules_dotnet//dotnet/toolchain:${DOTNET_TOOLCHAIN} --platforms=@io_bazel_rules_dotnet//dotnet/toolchain:${DOTNET_TOOLCHAIN} @io_bazel_rules_dotnet//tools/nuget2bazel:nuget2bazel.exe --"

# Clear output files
if [ -f "${OUTPUT_DIR}/${FILE_NAME}" ]; then
    rm "${OUTPUT_DIR}/${FILE_NAME}"
fi
if [ -f "${OUTPUT_DIR}/nuget2config.json" ]; then
    rm "${OUTPUT_DIR}/nuget2config.json"
fi

# Build template
cat <<EOF > "${OUTPUT_DIR}/${FILE_NAME}"
load("@io_bazel_rules_dotnet//dotnet:defs.bzl", "nuget_package")

# Backwards compatibility definitions
def nuget_protobuf_packages():
    nuget_rules_proto_grpc_packages()

def nuget_grpc_packages():
    nuget_rules_proto_grpc_packages()

def no_op():
    # Function that does nothing, to be placeholder in below function. This prevents it being a
    # syntax error when nuget2bazel is first run
    pass

def nuget_rules_proto_grpc_packages():
    no_op()

    ### Generated by the tool
    ### End of generated by the tool
EOF

# Add deps
${TOOL} add --path "${OUTPUT_DIR}" --indent --bazelfile "${FILE_NAME}" Google.Protobuf "${PROTOBUF_VERSION}"
${TOOL} add --path "${OUTPUT_DIR}" --indent --bazelfile "${FILE_NAME}" Grpc.Net.Client "${GRPC_VERSION}"
${TOOL} add --path "${OUTPUT_DIR}" --indent --bazelfile "${FILE_NAME}" Grpc.AspNetCore "${GRPC_VERSION}"

# Clear packages directory
if [ -d "${OUTPUT_DIR}/packages" ]; then
    rm -r "${OUTPUT_DIR}/packages"
fi

# Patch in buildifier fixes
cat "${OUTPUT_DIR}/${FILE_NAME}" | python3 -c "import sys; sys.stdout.write('\"\"\"Generated nuget packages\"\"\"\n\n' + sys.stdin.read().replace('def nuget_rules_proto_grpc_packages():', 'def nuget_rules_proto_grpc_packages():\n    \"\"\"Nuget packages\"\"\"'))" | sponge "${OUTPUT_DIR}/${FILE_NAME}"
