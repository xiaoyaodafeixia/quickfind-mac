# QuickFind · macOS 文件名秒搜

给 macOS 一个 Everything 级别的文件名搜索：**不装任何第三方索引服务**，直接读 Spotlight 现成的索引（`mdfind`），全盘 0.1–0.3 秒出结果；Spotlight 搜不到的盲区，用 `find` 直扫补齐。一个 AppleScript 小 app + 一个 zsh 脚本，零第三方依赖。

```
git clone https://github.com/<你的用户名>/quickfind-mac.git
cd quickfind-mac
./build.sh      # 构建 → dist/QuickFind.app
./install.sh    # 安装到 ~/Applications（检测到 DSH 会顺带同步 skill）
```

## 为什么不是「再装个搜索软件」

macOS 本来就有全盘索引（Spotlight，后台服务 mds），`mdfind` 就是直接读它。你在 App Store 买的 HoudahSpot、Tembo，或 Raycast / Alfred 里的搜索扩展，**底层全是同一份索引**——换个界面治不了「搜不到」。

「搜不到」的真实原因几乎都是索引盲区：

| 盲区 | 说明 |
|---|---|
| 点目录 | `~/.config`、`~/.ssh`、`~/.npm`、`~/.cache` 等默认不进 Spotlight 索引 |
| `~/Library` 深处 | Application Support 里的文件时有时无 |
| 未建索引的外接盘 | 新插的盘还没被 Spotlight 索引 |
| exFAT / NTFS 盘 | 文件系统本身不支持 Spotlight 索引，永远搜不到 |

### 外接盘三种情况

| 情况 | 现象 | 处理 |
|---|---|---|
| 已建索引 | `mdfind` 直接命中 | 不用管 |
| 未建索引 | 快搜搜不到 | GUI 里点「建索引」（`mdutil -i on`），或直接用深搜 |
| exFAT / NTFS | 建不了索引 | 只能深搜（find 直扫） |

## 双引擎

- **快搜**：`mdfind -name 关键词`，读索引，全盘 0.1–0.3 秒
- **深搜**：快搜结果 + `find` 直扫盲区——点目录、`~/Library/Application Support`、Homebrew、家目录 4 层、**全部外接卷** 6 层；几秒内出结果

## 命令行用法

```bash
src/quickfind-core.sh 关键词                 # 快搜
src/quickfind-core.sh 关键词 deep            # 深搜
src/quickfind-core.sh 关键词 deep --limit 20 # 深搜 + 限 20 条
QUICKFIND_EXTRA_DIRS="$HOME/Downloads:/data" src/quickfind-core.sh 关键词 deep
```

输出每行一个绝对路径（已去重、已排除 node_modules/.git/缓存），可以直接接管道：

```bash
src/quickfind-core.sh report | head -5                  # 看前 5 条
src/quickfind-core.sh 备忘录 | xargs -I{} open -R {}    # 逐条在 Finder 里定位
```

| 参数 / 环境变量 | 作用 |
|---|---|
| `--limit N` / `QUICKFIND_LIMIT` | 最多输出 N 条，默认不限 |
| `QUICKFIND_EXTRA_DIRS` | 深搜追加目录，冒号分隔 |
| `QUICKFIND_FIND_DEPTH` | 深搜直扫深度，默认 7 |
| `-h` | 完整说明 |

### v1.1 相对初版的改进

- 新增 `--limit N`、`-h`、`QUICKFIND_EXTRA_DIRS`、`QUICKFIND_FIND_DEPTH`
- 空关键词从静默 `exit 0` 改为用法提示 + `exit 2`（GUI 调用前已判空，不受影响）
- 未知参数显式报错退出，不再被静默当成快搜

## GUI（QuickFind.app）

- 快搜 / 深搜两个按钮；结果列表选中后「定位」在 Finder 里显示该文件（`open -R`）
- 检测到外接盘没建索引时，给一个「建索引」按钮（`mdutil -i on`，需要管理员密码；exFAT/NTFS 会提示不支持）
- 结果最多列 400 条
- 首次运行 macOS 会问「QuickFind 想要控制 Finder / 访问文件」，点允许即可

## 构建 / 安装 / 定制

- `build.sh`：`osacompile` 编译 AppleScript → 删掉 osacompile 默认塞入的 10 条用不到的隐私权限声明 → 把搜索核心拷进 `Contents/Resources/` → ad-hoc 签名，产物在 `dist/QuickFind.app`
- `install.sh`：装到 `~/Applications`（用户目录，不需要 sudo）；检测到 `~/.dsh/skills` 就同步 DSH skill
- app 本体 = `src/QuickFind.applescript`（纯 AppleScript），搜索核心 = `src/quickfind-core.sh`（zsh），app 运行时调用 app 内 `Contents/Resources/` 里那份
- 常改点：结果上限（AppleScript 里 `maxRows:400`）、盲区目录列表（core 脚本 B1 段）、直扫深度
- 改完源码重跑 `./build.sh` 即可；**改 core 后必须重新构建**，否则 app 里还是旧核心

## 搜不到？先怀疑索引本身

如果 `mdfind` 连刚建的文件都搜不到，多半是索引坏了：

```bash
sudo mdutil -E /    # 重建系统盘索引（后台跑，期间搜索不全）
mdutil -s /         # 查看索引状态
```

另外：系统设置 → Spotlight → 隐私里被排除的目录，是用户主动排除的，任何工具都不该搜。

## 已知限制

- 只搜文件名，不搜内容（搜内容用 `mdfind` 全文或 `rg`）
- exFAT/NTFS 盘只能力深搜，快搜帮不上
- 深扫超大目录会到十几秒，取决于目录规模

## License

MIT。作者：xiaoyaodafeixia & DSH agents（初版：沈砚；工程化：星期五）。
