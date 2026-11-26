# Tipwink 正式版发布规范

正式版固定用 Sparkle 读取现有 Tipwink 香港 OSS 的独立 `public/stable/` 正式目录下的 HTTPS `appcast.xml`。GitHub Releases 和 OSS 必须提供同一份 ZIP。官网继续链接 GitHub 下载。内测地址、Apple Development 签名和内测发布脚本不用于正式分发。

正式清单固定为 `https://tipwink-updates-6ee43e7763.oss-cn-hongkong.aliyuncs.com/public/stable/appcast.xml`。

## 一次性准备

- 沿用 0.7.0 已验收的 Xcode 自动 Developer ID 签名和公证路径，在发布 Mac 检查 Xcode 登录和所属团队；不能只用 `security find-identity` 的本地结果判断自动导出是否可用。正式渠道使用单独的 Sparkle EdDSA 密钥。Sparkle 私钥留在发布 Mac 的钥匙串，依既有安全流程备份。仓库、参数、日志和聊天不收录私钥、OSS 或 GitHub 凭据、公证凭据。App 内只放公钥。
- 为正式源建立与内测隔离的 OSS 路径和固定 HTTPS 地址。桶保持私有，只开放正式清单和正式 ZIP 的匿名 HTTPS 读取，不扩大 ACL，不开放匿名列举或写入，不改变内测策略；发布身份只给该路径所需的权限。包按版本命名、禁止覆盖；清单必须可及时重新验证。正式 feed URL 与公钥一旦随公开包发出，变更应另做经过测试的迁移，不能临时换。
- 在本机配置中保存非秘密参数和本机已配置的 profile 名称。正式、验收两套地址分开。不要把配置文件传进仓库。只有一台指定发布机可写正式路径，避免并行推广。

## 每次发布

1. 从干净的已合并源码构建，记录提交，确认 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION` 同时递增。构建 Release 时传入 `TIPWINK_APPCAST_URL` 和 `TIPWINK_UPDATE_PUBLIC_KEY`，保持 bundle ID 和 Developer ID 团队一致。
2. Release 归档必须显式使用 `CODE_SIGN_STYLE=Manual`、`CODE_SIGN_IDENTITY=Apple Development` 和发布配置的 `DEVELOPMENT_TEAM`，不要沿用开发构建的临时签名（`-`）。提交公证或打开 Organizer 前，先跑 `scripts/verify-release-archive PATH.xcarchive EXPECTED_TEAM`。未通过就重建，不交给用户重试。Apple Development 只用于中间归档，不用于正式分发。随后沿用 `method=developer-id`、`signingStyle=automatic` 的 Developer ID 导出路径，固定 `manageAppVersionAndBuildNumber=false`，允许已登录 Xcode 的签名流程处理身份。完成公证、绑定并验证公证票据，再用 `ditto -c -k --keepParent` 打包。保留最终 ZIP，不要在 Sparkle 签名后重新压缩。命令行报 `No Accounts` 时，不能仅凭这一条断定用户没登录；可用已过归档检查的同一份产物在 Xcode Organizer 走 Developer ID → Upload。用锁定版本的 Sparkle 工具生成正式签名清单，版本化 OSS ZIP 名称用 `Tipwink-<版本>-macOS-arm64.zip`。签名公钥应与正式包内公钥一致。
3. 运行 `scripts/release-public verify --help` 查看发布前检查参数。校验从最终 ZIP 中提取的 App：正式 feed、签名公钥、签名清单开关、预期版本和构建、安装要求、Developer ID、公证和 Sparkle 签名。先在隔离环境用同一最终 ZIP 做升级验收，记录版本和 SHA-256、从正确的基线能够发现新版、下载、安装、重启，检查用户设置保留。正式源切换后，再次检查应显示无更新（而非网络错误）。不要用开发包或只看 HTTP 200 代替。
4. 只把过检的 ZIP 推广到正式版，先上传不可变的 OSS ZIP 并回读，再校验 GitHub 草稿的同一份 ZIP。正式 feed 最后更新；不以看到 Release 页面为结束。
5. 运行 `scripts/release-public verify-live --help` 查看公网回读参数。核对正式源和两个下载地址的实际字节、签名、版本。用实际的上一正式版本完成生产渠道网络验证和必要的真机回归。保留提交、版本、构建号、ZIP 和清单哈希、两个地址、验收证据以及未通过的步骤。任何一步失败，状态是「未完成」。重试使用同一份签名文件，已存在对象内容不符就停；不要覆盖原包。已升级设备不会自动降级；修正既有坏包用更高构建号，保留早期已验证文件。

## 0.7.1 首次迁移

GitHub 正式包 0.6.3、0.6.4、0.7.0 没有 Sparkle 更新配置，不能通过其应用内按钮迁移。0.7.1 的发布说明必须写明先退出旧版，下载并替换「应用程序」中的 Tipwink，一次即可。用保持同一签名身份且构建号较低的测试客户端，绑定隔离的验收源，实际升级到**最终正式 ZIP**；验收源用单独签名清单引用同一文件。再手动安装正式 ZIP，验证正式源以及同构建号时显示无更新。0.7.1 发布后，下一版要用真实的上一正式分发包做升级验收。

已批准的常规发布沿用上述默认项，不重复确认签名方式、OSS 地域和目录。仅遇到需要本人登录、扩大访问权限、替换签名身份或正式源迁移时才请项目负责人处理。

不要把在 Linux 上通过的结构或单元测试、GitHub 上的构建包、或者一次成功公证当成 Mac 的升级验收。

## 发布入口与验收记录

`scripts/publish-public` 只在发布 Mac 执行。它要求本地验收记录与最终 ZIP、提交、版本及构建号完全对应，通过后才上传。它会在同一流程回读两个下载源，最后更新 OSS 清单，再执行公网校验。运行 `scripts/publish-public --help` 查看参数。配置 JSON 仅含 `bucket`、`region`、`endpoint`（`oss-<region>.aliyuncs.com`）、`prefix`（`public/<channel>`）、`profile`、`team`、`sparkle_bin`、`keychain_account`，不要填凭据。首次正式发布才加 `--bootstrap`，只有完成审查才加 `--publish`。

验收记录填入实际的 `zip_sha256`、`source_commit`、`version`、整数 `build`、`from_version`、整数 `from_build`、不含隐私或凭据的 `evidence`，以及五项实测结果 `discovery`、`download`、`install`、`relaunch`、`settings_preserved`。只在实际操作通过后填 `true`。证据不上传到公开 Release。代码验证记录与产物一致，不替代观察到的真机操作。
