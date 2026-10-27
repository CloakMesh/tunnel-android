# CloakMesh Android 客户端

CloakMesh 的 Android 客户端，fork 自 [OpenZiti ziti-tunnel-android](https://github.com/openziti/ziti-tunnel-android)（Apache License 2.0）。

> **上游说明**：VpnService 隧道、SDK 绑定与拦截逻辑全部来自上游。CloakMesh 目前仅增加中文文档与仓库归属说明。

## 当前状态

| 项目 | 状态 |
|---|---|
| 代码 | 与上游 `main` 同步 |
| 中文文档 | ✅ 本文件 |
| 中文界面 | ⏳ 待做（需 Android SDK 构建 + 真机验证） |
| 品牌化（applicationId / 应用名 / 图标） | ⏳ 待做（applicationId 变更会影响升级与推送，需一次性规划） |

## 构建

```bash
git clone https://github.com/aiuc-labs/cloakmesh-tunnel-android.git
cd cloakmesh-tunnel-android
./gradlew assembleDebug
```

依赖 Android SDK 与 NDK（本仓库包含 ziti-sdk-android 的原生依赖）。

## 与其它仓库的关系

| 仓库 | 关系 |
|---|---|
| `cloakmesh-core` | 控制器/路由器 |
| `cloakmesh-console` | 管理控制台 |
| `cloakmesh-tunnel-sdk-c` | 隧道引擎（Android SDK 的底层实现来源） |

## 许可

Apache License 2.0，与上游一致。