#!/bin/bash
set -e

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Setup ANGLE if needed
if [ ! -d "angle" ]; then
    source ./setup-angle-unix.sh
else
    # Add depot_tools to PATH
    export PATH="$PATH:$SCRIPT_DIR/depot_tools"
fi

# Ensure Vulkan SDK / libraries are installed
echo "Checking Vulkan development libraries..."
if ! ldconfig -p | grep -q libvulkan.so; then
    echo "Vulkan libraries not found! Installing Vulkan SDK..."
    sudo apt update
    sudo apt install -y libvulkan-dev
fi

# Go to ANGLE directory
cd angle

# Common GN args for Linux builds with Vulkan
COMMON_ARGS='
    is_debug=false
    is_component_build=false
    angle_enable_gl=true
    angle_enable_vulkan=true
    angle_standalone=true
    angle_build_tests=false

    # Enable official build optimizations
    is_official_build=true
    chrome_pgo_phase=0

    # Disable unused backends
    angle_enable_d3d9=false
    angle_enable_d3d11=false
    angle_enable_metal=false
    angle_enable_null=false
    angle_enable_wgpu=false

    # Language settings
    angle_enable_essl=false
    angle_enable_glsl=true

    # Optimize for size
    symbol_level=0
    strip_debug_info=true
    angle_enable_trace=false
'

# Build for Linux x86_64
echo "Building ANGLE for Linux x86_64 with Vulkan..."
gn gen out/linux-release-x86_64 --args="
    target_os=\"linux\"
    target_cpu=\"x64\"
    $COMMON_ARGS
"
ninja -C out/linux-release-x86_64 libEGL.so libGLESv2.so

# Create directory structure
rm -rf ../build/linux/x86_64/lib
mkdir -p ../build/linux/x86_64/lib
cp -R out/linux-release-x86_64/*.so ../build/linux/x86_64/lib/

# Build for Linux ARM64
echo "Building ANGLE for Linux ARM64 with Vulkan..."
gn gen out/linux-release-arm64 --args="
    target_os=\"linux\"
    target_cpu=\"arm64\"
    $COMMON_ARGS
"
ninja -C out/linux-release-arm64 libEGL.so libGLESv2.so

rm -rf ../build/linux/arm64/lib
mkdir -p ../build/linux/arm64/lib
cp -R out/linux-release-arm64/*.so ../build/linux/arm64/lib/

# Copy headers
echo "Copying headers..."
mkdir -p build/linux/x86_64/include/{EGL,GLES2,GLES3,KHR}
mkdir -p build/linux/arm64/include/{EGL,GLES2,GLES3,KHR}

for ARCH in x86_64 arm64; do
    cp -R angle/include/EGL/*.h build/linux/$ARCH/include/EGL/
    cp -R angle/include/GLES2/*.h build/linux/$ARCH/include/GLES2/
    cp -R angle/include/GLES3/*.h build/linux/$ARCH/include/GLES3/
    cp -R angle/include/KHR/*.h build/linux/$ARCH/include/KHR/
done

echo "Linux builds complete! Libraries are available in:"
echo "  - build/linux/x86_64/lib"
echo "  - build/linux/arm64/lib"
echo "Headers are included in the include directory within each build folder."