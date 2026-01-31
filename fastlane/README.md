fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac release

```sh
[bundle exec] fastlane mac release
```

完整的发布流程：构建、签名、公证、创建 DMG

### mac build_app_release

```sh
[bundle exec] fastlane mac build_app_release
```

构建 Release 版本的应用

### mac create_dmg

```sh
[bundle exec] fastlane mac create_dmg
```

创建 DMG 安装包

### mac notarize_dmg

```sh
[bundle exec] fastlane mac notarize_dmg
```

公证 DMG 文件

### mac notarize_only

```sh
[bundle exec] fastlane mac notarize_only
```

公证已存在的 DMG 文件

### mac test_build

```sh
[bundle exec] fastlane mac test_build
```

测试构建（跳过公证）

### mac clean

```sh
[bundle exec] fastlane mac clean
```

清理构建文件和缓存

### mac validate

```sh
[bundle exec] fastlane mac validate
```

验证 Fastlane 配置

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
