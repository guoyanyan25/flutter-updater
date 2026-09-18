# Flutter App 版本更新服务（GitHub 托管）

本仓库用于配合 Flutter App 实现「启动自动检测版本 → 弹窗提示 → 下载 APK → 安装」的完整自更新能力。

## 仓库结构

```
flutter-updater/
├── version.json              # 版本信息配置文件（核心）
├── apk/                      # 放置 APK 的占位目录
│   └── README.md
├── README.md
└── .github/
    └── workflows/
        └── release.yml       # GitHub Actions 自动构建（可选）
```

## 使用步骤

### 1. 修改 version.json

把 `apk_url` 里的「你的用户名」和「flutter-updater」换成你自己的仓库信息。

### 2. 发布 APK

1. 仓库页面 → 右侧 **Releases** → **Create a new release**
2. Tag version 填：`v1.0.0`
3. Release title 填：`v1.0.0 首次发布`
4. 上传你的 `app-release.apk`
5. 点 **Publish release**

### 3. 获取 APK 的 sha256（可选，推荐）

```bash
certutil -hashfile app-release.apk SHA256
```
把输出填到 `version.json` 的 `apk_sha256` 字段。

### 4. 如何发布新版本

1. 本地构建：`flutter build apk --release`
2. 修改 `version.json` 的 `latest_version` 为新版本号
3. 更新 `apk_url` 里的版本号
4. 提交并推送 version.json
5. 创建新的 GitHub Release，上传新 APK

## 注意事项

- APK 必须与已安装 App **同包名、同签名**，否则会提示「应用未安装」
- 不要把 `key.jks` / `key.properties` 提交到仓库
- iOS 无法用此方式自更新，需跳 App Store
