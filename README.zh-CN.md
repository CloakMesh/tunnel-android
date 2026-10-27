# CloakMesh Mobile Edge（Android）

CloakMesh 的 Android 客户端，fork 自 [OpenZiti ziti-tunnel-android](https://github.com/openziti/ziti-tunnel-android)（Apache License 2.0）。

> **上游说明**：VpnService 隧道、SDK 绑定与拦截逻辑全部来自上游。CloakMesh 的差异是用上游自带的**白标（white-label）机制**换了应用标识、显示名与品牌资源，另加中文文档与构建脚本；**没有改动任何 Kotlin/C++ 源码**。

## 与上游的差异

| 项目 | 上游默认 | CloakMesh | 实现方式 |
|---|---|---|---|
| applicationId | `org.openziti.mobile` | `com.cloakmesh.mobile` | `whitelabel.properties` |
| 应用显示名 | Ziti Mobile Edge | CloakMesh Mobile Edge | `whitelabel/cloakmesh/res/values/strings.xml` |
| 构建变体 | 无 flavor | `cloakmesh` flavor（`assembleCloakmeshDebug/Release`） | 同上 |
| 中文文档 + 构建脚本 | — | `README.zh-CN.md` + `scripts/build-android.sh` | — |
| 中文界面 | — | 简体中文（65 条全量翻译，`app/src/cloakmesh/res/values-zh`） | ✅ |
| 应用图标 | Z 字样图标 | 盾形 + 网格节点（自适应图标 + 5 密度 PNG + 通知栏单色标识） | ✅ |

上游本来就提供白标能力（见 `WhiteLabeling.md`），所以这是**官方支持的品牌化路径**，不会和上游代码产生冲突。

## 前置条件

| 组件 | 版本 | 说明 |
|---|---|---|
| JDK | **21** | 项目里 `kotlin { jvmToolchain(21) }`，JDK 17 会失败 |
| Android SDK Platform | **37**（`platforms;android-37.0`） | `compileSdk = 37` |
| Build-Tools | **37.0.0** | |
| NDK | **30.0.16248370** | `tunnel` 模块含 C++（`tunnel.cpp` 等），没有 NDK 编不了 |
| CMake | **3.22.1** | NDK 构建用（必须进 PATH，tunnel 模块直接调 `cmake --preset`） |
| **vcpkg** | 任意近期版本 | `tunnel` 模块用 vcpkg 编译原生依赖：libuv / openssl / zlib / llhttp / libsodium / protobuf-c / stc / json-c，**8 个库 × 4 个 Android ABI** |
| Gradle | **9.8.2** | AGP 9.4.1 要求 Gradle 9.x；仓库自带 wrapper |

一次性安装（macOS）：

```bash
SDK=$HOME/android-build/sdk
$SDK/cmdline-tools/latest/bin/sdkmanager \
  'platforms;android-37.0' 'build-tools;37.0.0' 'ndk;30.0.16248370' 'cmake;3.22.1'

# vcpkg（原生依赖；首次会为 4 个 ABI 编译 OpenSSL 等，约 30–60 分钟）
git clone https://github.com/microsoft/vcpkg.git ~/android-build/vcpkg
~/android-build/vcpkg/bootstrap-vcpkg.sh -disableMetrics
export VCPKG_ROOT=~/android-build/vcpkg

# JDK 21（若没有）
curl -L -o jdk21.tar.gz https://mirrors.huaweicloud.com/openjdk/21.0.2/openjdk-21.0.2_macos-aarch64_bin.tar.gz
tar -xzf jdk21.tar.gz -C ~/android-build
```

## 构建

```bash
export JAVA_HOME_21=$HOME/android-build/jdk-21.0.2.jdk/Contents/Home
export ANDROID_HOME=$HOME/android-build/sdk
export VCPKG_ROOT=$HOME/android-build/vcpkg

./scripts/build-android.sh              # 白标 Debug APK
./scripts/build-android.sh release      # 白标 Release（需签名环境变量）
./scripts/build-android.sh beta         # 无白标的原始 Debug 变体
```

弱网环境：`services.gradle.org` 拉 wrapper 常常超时，可以直接用本地 Gradle 发行版，并用国内镜像：

```bash
# 1) 国内镜像下载 gradle 发行版
curl -L -o gradle-9.8.2-bin.zip https://mirrors.cloud.tencent.com/gradle/gradle-9.8.2-bin.zip
unzip -q gradle-9.8.2-bin.zip -d ~/android-build

# 2) 指定 GRADLE_BIN 跳过 wrapper 下载
GRADLE_BIN=$HOME/android-build/gradle-9.8.2/bin/gradle ./scripts/build-android.sh
```

产物：`app/build/outputs/apk/<flavor>/debug/…apk`。

### Release 签名

白标的 release 包必须签名，通过环境变量提供（不要写进仓库）：

```bash
export RELEASE_KEYSTORE=/path/to/your.keystore
export RELEASE_KEYSTORE_PASSWORD=...
export RELEASE_KEY_ALIAS=...
export RELEASE_KEY_PASSWORD=...
./scripts/build-android.sh release
```

### 用 GitHub Actions 出包（推荐，不需要本地工具链）

本机若没有 Android 原生工具链（vcpkg 需要的 autoconf/automake/libtool 等），可直接用 CI：

- 工作流：`.github/workflows/build-android.yml`
- 触发：push 到 `main` 或手动 `workflow_dispatch`
- 产物：artifact `cloakmesh-debug-apk`（含 APK 与 `SHA256SUMS.txt`）

CI 里已经处理好的环境细节（都不需要你操心）：

| 环境 | 处理方式 |
|---|---|
| `android-actions/setup-android@v3` 失败 | 该 action 会装已下架的 `tools` 包，改为直接用 runner 预装 SDK |
| vcpkg baseline 找不到 | runner 预装的 vcpkg 是裁剪副本，CI 里自建完整克隆 |
| libsodium 构建失败 | 补装 `autoconf autoconf-archive automake libtool pkg-config ninja-build` |
| 版本号变成 `0.0.0-local` | checkout 用 `fetch-depth: 0` 取全量 tag，`git describe` 才有输出 |

实测（2026-10-27）：CI 构建成功，产出 `ziti-mobile-edge-cloakmesh-debug.apk`
（applicationId `com.cloakmesh.mobile.debug`，versionName `v0.25.0-16-g78f4022-debug`，含 arm64-v8a / armeabi-v7a / x86），
已在 arm64 API 35 模拟器安装并启动，主界面正常、无崩溃。

## 安装与首次运行

```bash
adb install -r app/build/outputs/apk/cloakmesh/debug/*.apk
```

1. 首次启动会请求建立 VPN 连接 → 允许（系统设置 → 网络 → VPN 里会出现 **CloakMesh Mobile Edge**）
2. 导入身份：从控制器侧生成 JWT（见下），在客户端里添加

### 连接到本项目部署的控制器

```bash
docker compose -f ../cloakmesh-core/deploy/linux/docker-compose.yml \
  --env-file ../cloakmesh-core/deploy/linux/.env \
  exec -T controller bash -lc '
    ziti edge login -u admin -p "$CLOAKMESH_PWD" -y https://127.0.0.1:${CLOAKMESH_CTRL_ADVERTISED_PORT} &&
    ziti edge create identity android-test --role-attributes clients --jwt-output-file /tmp/a.jwt &&
    cat /tmp/a.jwt' > android-test.jwt
```

把 `android-test.jwt` 导入客户端即可。手机需能访问控制器的 `CLOAKMESH_CTRL_PORT`（默认 1280）与路由器 `CLOAKMESH_ROUTER_PORT`（默认 3022），端口与证书注意事项见 [cloakmesh-core/deploy/linux/README.md](https://github.com/aiuc-labs/cloakmesh-core/blob/main/deploy/linux/README.md)。

## 构建耗时与依赖说明

`tunnel` 模块不是纯 Kotlin：它通过 CMake + vcpkg 编译 C++（`tunnel.cpp`、`keychain.cpp`、`logging.cpp`）并链接上面 8 个原生库，4 个 ABI 全量构建在 M4 上大约 **30–60 分钟**，且首次需要从 GitHub 拉 vcpkg 的 ports。之后的增量构建是秒级。

想跳过原生依赖构建（例如原生库已构建过）可用：`-PskipDependentBuild`。

## 中文界面与图标

- **中文**：`app/src/cloakmesh/res/values-zh/strings.xml`，跟随系统语言；也可在 Android 13+ 的「设置 → 应用 → CloakMesh Mobile Edge → 语言」单独指定。
- **图标**：由 `tools/gen-icons.py` 生成（盾形 + 网格节点，深蓝底 `#0B1622` + 青绿 `#2EE6C5`），覆盖自适应图标、传统 mipmap、通知栏图标（`drawable/z.png`）与仪表盘 logo（`appicon.png`）。
- 改图标只需调 `tools/gen-icons.py` 里的颜色/形状，然后 `python3 tools/gen-icons.py` 重新生成。

> **坑 2（已修）**：上游 `app/src/debug/res/` 里有 debug 专用图标（`drawable/ic_launcher.png` 102KB + 引用它的自适应 XML）。**buildType 源集优先级高于 flavor**，所以白标图标在 debug 包里会被遮蔽——必须在变体源集 `app/src/cloakmeshDebug/res/` 覆盖（应用名同理）。判断方法：看 `app/build/intermediates/merged_res_blame_folder/**/merge-*.json` 里该资源来自哪个源集。

> **坑 1（已修）**：`whitelabel.properties` 的 `resourceDir` **相对路径按 app 模块目录解析**。早期写成仓库根的 `whitelabel/cloakmesh/res`，导致资源根本没合并——表现为新增字符串在 R 里 unresolved、图标和翻译都不生效。正确写法是 `resourceDir=src/cloakmesh/res`（即 `app/src/cloakmesh/res`）。

## 已知限制
- **签名需自备**：官方 keystore 不提供；自签的包不能与 App Store 版本共存（applicationId 不同则互不影响）。
- **NDK 版本敏感**：`ndkVersion` 写死在 `gradle/libs.versions.toml`，升级上游时若未同步安装对应 NDK 会直接构建失败。

## 许可

Apache License 2.0，与上游一致。