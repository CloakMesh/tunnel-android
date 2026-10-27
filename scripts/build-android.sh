#!/usr/bin/env bash
#
# CloakMesh Android 客户端构建脚本
#
# 前置条件：
#   JDK 21（项目 kotlin { jvmToolchain(21) }）、Android SDK Platform 37、
#   Build-Tools 37.0.0、NDK 30.0.16248370、CMake 3.22.1（tunnel 模块含 C++ 源码）
#
# 用法：
#   ./scripts/build-android.sh                 # 白标 Debug APK
#   ./scripts/build-android.sh release         # 白标 Release APK（需签名环境变量）
#   ./scripts/build-android.sh beta            # 无白标的原始 Debug 变体
#
# 可选环境变量：
#   JAVA_HOME_21  指定 JDK 21 路径（默认 ~/android-build/jdk-21.0.2.jdk/Contents/Home）
#   ANDROID_HOME  指定 Android SDK（默认 ~/android-build/sdk）
#   GRADLE_BIN    指定本地 gradle 可执行文件（默认用仓库自带 ./gradlew）
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-debug}"
SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/android-build/sdk}}"
JAVA_HOME_21="${JAVA_HOME_21:-$HOME/android-build/jdk-21.0.2.jdk/Contents/Home}"
WL_ORG="$(grep -E '^org=' "$ROOT/whitelabel.properties" 2>/dev/null | cut -d= -f2 || echo)"

log()  { printf '\033[1;32m[cloakmesh]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[cloakmesh]\033[0m %s\n' "$*" >&2; exit 1; }

preflight() {
    [ -x "$JAVA_HOME_21/bin/java" ] || die "需要 JDK 21：未找到 $JAVA_HOME_21
  安装方式（macOS arm64）：
    curl -L -o jdk21.tar.gz https://mirrors.huaweicloud.com/openjdk/21.0.2/openjdk-21.0.2_macos-aarch64_bin.tar.gz
    tar -xzf jdk21.tar.gz -C ~/android-build
  或用 JAVA_HOME_21=<路径> 覆盖"
    local v
    v="$("$JAVA_HOME_21/bin/java" -version 2>&1 | head -1)"
    case "$v" in *21*) : ;; *) die "JDK 版本不符（需要 21）：$v" ;; esac

    [ -d "$SDK_ROOT/platforms" ] || die "未找到 Android SDK：$SDK_ROOT（用 ANDROID_HOME 指定）"
    [ -d "$SDK_ROOT/ndk" ] || die "缺少 NDK（tunnel 模块含 C++）。安装：
  \$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager 'ndk;30.0.16248370' 'cmake;3.22.1'"

    # tunnel 模块通过 vcpkg 编译 libuv/openssl/zlib/llhttp/libsodium/protobuf-c/stc/json-c
    # （8 个库 × 4 个 Android ABI），没有 VCPKG_ROOT 时 CMake 配置阶段就会失败
    if [ -z "${VCPKG_ROOT:-}" ] && [ ! -d "$HOME/android-build/vcpkg" ]; then
        die "缺少 vcpkg（tunnel 模块的原生依赖由 vcpkg 构建）。安装：
  git clone https://github.com/microsoft/vcpkg.git ~/android-build/vcpkg
  ~/android-build/vcpkg/bootstrap-vcpkg.sh -disableMetrics
  export VCPKG_ROOT=~/android-build/vcpkg
提示：首次构建会为 4 个 ABI 编译 OpenSSL 等依赖，耗时约 30-60 分钟。"
    fi
    export VCPKG_ROOT="${VCPKG_ROOT:-$HOME/android-build/vcpkg}"
    [ -x "$VCPKG_ROOT/vcpkg" ] || die "vcpkg 未初始化：$VCPKG_ROOT（执行 bootstrap-vcpkg.sh）"

    # CMake 由 Android SDK 提供，必须进 PATH（tunnel 模块直接调用 cmake --preset）
    local sdk_cmake
    sdk_cmake="$(find "$SDK_ROOT/cmake" -maxdepth 2 -name bin -type d 2>/dev/null | head -1)"
    [ -n "$sdk_cmake" ] || die "缺少 SDK 自带 cmake：sdkmanager 'cmake;3.22.1'"
    case ":$PATH:" in *":$sdk_cmake:"*) : ;; *) export PATH="$sdk_cmake:$PATH" ;; esac
}

build() {
    export JAVA_HOME="$JAVA_HOME_21"
    export ANDROID_HOME="$SDK_ROOT"
    export ANDROID_SDK_ROOT="$SDK_ROOT"
    cd "$ROOT"

    local task
    case "$MODE" in
        debug)   [ -n "$WL_ORG" ] || die "未找到 whitelabel.properties 的 org，无法确定任务名"
                 task="assemble$(printf '%s' "${WL_ORG:0:1}" | tr '[:lower:]' '[:upper:]')${WL_ORG:1}Debug" ;;
        release) [ -n "$WL_ORG" ] || die "未找到 whitelabel.properties 的 org"
                 [ -n "${RELEASE_KEYSTORE:-}" ] || die "Release 需要签名环境变量：RELEASE_KEYSTORE / RELEASE_KEYSTORE_PASSWORD / RELEASE_KEY_ALIAS / RELEASE_KEY_PASSWORD"
                 task="assemble$(printf '%s' "${WL_ORG:0:1}" | tr '[:lower:]' '[:upper:]')${WL_ORG:1}Release" ;;
        beta)    task="assembleDebug" ;;
        *)       die "未知模式：$MODE（debug|release|beta）" ;;
    esac

    # 注意：settings.gradle.kts 把 :app 重命名成 :ziti-mobile-edge，
    # 所以用不带项目前缀的任务名，避免路径变化导致任务找不到
    log "构建任务：$task"
    # GRADLE_BIN 可指向本地 gradle 发行版（弱网/内网环境不必走 wrapper 下载）
    local gradle_bin="${GRADLE_BIN:-./gradlew}"
    "$gradle_bin" --no-daemon "$task"
}

collect() {
    local dir
    dir="$ROOT/app/build/outputs/apk"
    log "产物："
    find "$dir" -name '*.apk' -newermt '-2 hours' 2>/dev/null | while read -r f; do
        printf '  %s (%s)\n' "$f" "$(du -h "$f" | cut -f1)"
    done
    cat <<EOF

安装到设备/模拟器：
  adb install -r <上面的 apk>

首次要在设备上允许 VPN：系统设置 → 网络 → VPN → CloakMesh Mobile Edge
EOF
}

preflight
build
collect