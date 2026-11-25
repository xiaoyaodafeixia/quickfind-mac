---
name: mac-file-search
description: macOS 上按文件名秒级找文件（Windows Everything 的 Mac 等价物）：mdfind 读 Spotlight 索引 0.1-0.3s，索引盲区（点目录、~/Library 深处、未建索引/不支持索引的外接盘）用 find 直扫补齐。可选 GUI（QuickFind.app，本仓库 src/ 构建）。
---

# mac-file-search

## 核心结论

- **不要推荐第三方搜索软件**。HoudahSpot / Tembo / Raycast / Alfred 全是 Spotlight 同一份索引的前端，换界面治不了「搜不到」。
- 搜不到的真实原因是索引盲区，用 find 直扫补齐。

## 盲区

| 盲区 | 说明 |
|---|---|
| 点目录 | ~/.config ~/.ssh ~/.npm ~/.cache 等默认不进索引 |
| ~/Library 深处 | Application Support 时有时无 |
| 未建索引外接盘 | 新盘没索引过 |
| exFAT/NTFS 盘 | 文件系统不支持索引，永远快搜不到 |

## 用法（本 skill 的 scripts/quickfind-core.sh）

```bash
scripts/quickfind-core.sh 关键词              # 快搜（索引，0.1-0.3s）
scripts/quickfind-core.sh 关键词 deep         # 深搜（索引 + find 直扫盲区）
scripts/quickfind-core.sh 关键词 deep --limit 20
QUICKFIND_EXTRA_DIRS="$HOME/Downloads:/data" scripts/quickfind-core.sh 关键词 deep
```

深搜覆盖：B1 点目录 + ~/Library/Application Support + Homebrew（深度 QUICKFIND_FIND_DEPTH 默认 7）；B2 家目录 4 层；B3 全部外接卷 6 层（跳过 Macintosh HD 与 com.apple.* 伪卷）。输出每行一个绝对路径，已去重、已滤 node_modules/.git/缓存。

## 可选 GUI

QuickFind.app（仓库根目录 ./build.sh 构建，./install.sh 装）。安装位置因机器而异（常见 `~/Applications/QuickFind.app`）。功能：快搜/深搜按钮、外接盘无索引时给「建索引」（mdutil -i on，需管理员密码）、定位（open -R）、最多 400 条。

## 排障

- 索引状态：`mdutil -s /`（或指定卷）
- 索引损坏（mdfind 连新文件都搜不到）：`sudo mdutil -E /` 重建
- 系统设置 → Spotlight → 隐私里排除的位置任何工具都搜不到，属正常

## 反触发

搜文件内容用 `mdfind` 全文检索或 rg；查应用设置项不走本 skill。
