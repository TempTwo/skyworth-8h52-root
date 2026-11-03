# 事故复盘：误删系统 APK 变砖与恢复

> 记录时间：2026-10-22
> 事故：清理 `/system` 上"未安装的占位 APK"时，匹配逻辑写错，删掉了 54 个 APK，
> 其中 25 个是**已安装的系统 APK**（HiRMService、SkyRMService、webview、Shell、
> InputDevices、SettingsProvider、SkyPackageInstaller、loostone.tuning 等），
> 电视开机卡在 logo，无法进入系统。

---

## 0. 结论速览

| 项 | 值 |
| --- | --- |
| 变砖原因 | `cleanup-system-orphans.sh` 匹配 `pm list packages -f` 输出失败 → 误删已安装系统 APK |
| 后果 | `/system` 缺 25 个已安装 APK，且边删边 remount ro 可能损坏 ext4 日志 |
| 恢复路径 | U 盘放**创维原厂 OTA 全量升级包** → recovery「使用U盘或SD卡升级」整包刷回 |
| 固件来源 | `http://update01.skyworth-cloud.com/pup/8H52_G3_V017.012.060_9_online.zip` |
| 用时 | 从定位固件到电视开机约 2 小时 |

---

## 1. 为什么会删错

脚本原本想删"**占位但不安装**"的系统 APK（它们占着空间，PackageManager 不认识，删了无碍）：

```sh
pm list packages -f 2>/dev/null | $BB sed 's/^package://' > .installed_paths
for apks in /system/app/*/*.apk ...; do
    $BB grep -qx "$apks" .installed_paths && continue   # 已安装，保留
    $BB rm -f "$apks"
done
```

**但 `pm list packages -f` 的输出格式是**：

```
package:/system/app/HiRMService/HiRMService.apk=com.hisilicon.android.hiRMService
```

即 `package:<路径>=<包名>`。脚本只剥掉了 `package:` 前缀，**没剥掉 `=包名` 后缀**，
于是每一行都变成了 `路径=包名`，和裸路径 `grep -qx` 永远匹配不上 → **所有 APK 都被判为"未安装"并删除**。

### 教训

1. **不要用 `grep -qx` 做"精确匹配"除非两边格式完全一致**。先把两边规范化到同一形式。
2. **删除系统分区里的文件前，先做一次"假如全删了会怎样"的推演**：
   PackageManager 认的是 `/data/system/packages.xml`，它记录了已安装包的**路径**。
   删掉一个已安装包的 APK，PackageManager 仍认为它已安装，
   但文件没了 → 开机时 PackageManager 扫到"已安装但文件缺失"→ 反复崩溃 / 卡 logo。
3. **备份要在删除之前**，而且备份要能被验证（`tar -tf` 能列出来）。

---

## 2. 卡在 logo 后的排查

| 检查 | 结果 |
| --- | --- |
| recovery 菜单能否进 | ✅ 能（使用U盘或SD卡升级 / 清除所有数据 / 重启 三项） |
| 「清除所有数据」是否有效 | ❌ 无效（问题在 `/system`，不在 `/data`） |
| recovery 有无网络 | ❌ 无（ARP 里 192.168.0.9 为 incomplete） |
| recovery 有无 adbd(5555) | ❌ 无监听 |
| `/system` 挂载 | ✅ ext4（`/dev/block/platform/hi_mci.1/by-name/system`） |

结论：问题锁定在 `/system`，只能靠**整包刷回**解决。

---

## 3. 固件从哪来

创维的固件 CDN 是腾讯云 COS，本地 DNS 解析不了 `update01.skyworth-cloud.com`，
但用 8.8.8.8 能解析到 CNAME：

```
update01.skyworth-cloud.com → update01.skyworth-cloud.com.cdn20.com
  → 218.29.49.10 / 58.242.249.137
```

带上 Host 头直连即可：

```bash
curl --resolve update01.skyworth-cloud.com:80:218.29.49.10 \
     -o fw.zip http://update01.skyworth-cloud.com/pup/8H52_G3_V017.012.060_9_online.zip
```

### 命名规律

```
<板号>_<机芯>_V<版本>_<序号>[_<子版本>].zip
```

实例：

| 文件名 | 说明 |
| --- | --- |
| `8H73_E6000_V016.011.251_9_5.5.zip` | 8H73 / E6000 机芯 |
| `8S87_S9300_V016.012.060_9.zip` | 8S87 / S9300 |
| `8H52_G3_V017.012.060_9_online.zip` | **本机**：8H52 / G3 机芯 |

路径前缀只有两个：`/pup/` 和 `/pup_v1/`（新包用 v1）。CDN **没有目录列表**，
只能按名字猜 + HEAD 探测。

### 为什么是 V017 而不是电视原来的 V022

电视原本是 `022.011.080`（`ro.build.upgrade.name=8H52_G3_8H55_V7`）。
扫了 10752 种命名组合，CDN 上**只有 V017 的两个包**（`V017.012.060` 和 `V017.007.190`）。

V017 是**同板号、同机芯**的原厂全量包，刷它足以把 `/system` 刷回原样
（找回那 25 个 APK），属于"先救活、再 OTA 升级"的正规流程。
事实上电视刷完 V017 后，**自己在线升到了 V020.006.110**。

---

## 4. U 盘升级怎么操作

### 包的结构

`8H52_G3_V017.012.060_9_online.zip` 是标准 AOSP OTA 包（632 MB）：

```
META-INF/com/google/android/update-binary
META-INF/com/google/android/updater-script
system.img.unsparse        1.34 GB   ← ext4 原始镜像
boot.img / recovery.img / logo.img / panel.img / fastboot.img
Hi3751V551.dtb / tcon.bin / atf.bin / bootargs.img
atv/  factory/  preinstall/
VersionInfo/build.prop
```

`updater-script` 里的三条断言正好对应本机：

```sh
assert(getprop("ro.product.board")=="bigfish");
assert(getprop("ro.build.product")=="Hi3751V551");
assert(getprop("ro.product.name")=="Sky_V551_64bit_G3_2layer");
```

### recovery 认什么文件名

从 `recovery.img` 里 `strings` + 反汇编可确认，它找：

- `/mnt/usb/update.zip`
- `8H52_G3.zip`（板号专属名，`SKY find auto_update_file`）

**两个名字都放一份最保险。**

recovery 的 USB 挂载支持 **vfat**（`I:retrying mount %s with RO vfat`），
所以 FAT32 U 盘可以直接用，无需 NTFS。

### 操作步骤

1. Mac 上先**推出 U 盘**（macOS 挂着盘时电视读不到）
2. 电视**断电**（不是待机），插上 U 盘
3. 插回电源，**立刻长按遥控器「主页/Home」键**不放，直到出现 recovery 菜单
4. 选 **「使用U盘或SD卡升级」**（有的版本叫「从外部存储安装」）
5. 等 10～20 分钟，**中途别断电、别拔盘**
6. 完成后选「重启」

---

## 5. 这个包里有两个"缺件"（不影响救砖）

`updater-script` 引用了包内**没有**的两个东西：

```
L31  package_extract_file("skyworth.img.unsparse", ...)   ← 包内没有
L56  package_extract_dir("userdata", "/data")              ← 包内没有
```

查了其他机芯的官方包（`8H73_E6000_*`、`8H84_E6200_*`），
它们走的是**完全不同的分区布局**（`skydir.img` / `sdcard.img` / 逐文件 `system/`），
**根本没有 `skyworth` 分区**——说明 `updater-script` 是**多机芯共用模板**，
8H52_G3 这条线只有 `system` 一个分区。

而脚本的执行顺序是：

```
L27  package_extract_file("system.img.unsparse", .../system)   ← 刷 /system
L31  package_extract_file("skyworth.img.unsparse", ...)         ← 缺失 → abort
L61  package_extract_file("recovery.img", .../recovery)         ← 刷不到
L63  setmisc(... misc, "status_y")                             ← 执行不到
```

**关键：`/system` 在第 27 行就刷完了，早于第 31 行的缺失。**
所以虽然脚本中断，但我们要的东西（`/system` 恢复原样）已经拿到了。

没刷到的 `recovery` / `atv` / `factory` 分区保持原状 —— 对救砖无害
（`recovery` 本来就能用，`factory` 是屏幕参数，本来也是本机自己的才对）。

---

## 6. 刷完之后

| 项 | 状态 |
| --- | --- |
| 系统版本 | V017.012.060 → 随后**自动 OTA 升级**到 V020.006.110 |
| 包总数 | 20 → 59（找回全部系统 APK） |
| U 盘自愈脚本 | ✅ 自动执行：静态 IP、装 su、装 Aerial、改 DEFAULT_HOMEPAGE |
| 厂商 `hisi_boot_shell.sh` | V017 工厂版是**纯 LF**（816 字节，md5 `8bdc6bf1...`），语法正常 |
| Aerial 桌面 | ✅ 自动安装并接管 |

> 注意：`/system/bin/hisi_boot_shell.sh` 之前被 CRLF 弄坏过，那次**是我们自己**
> 用 `adb shell cat` 传输文件造成的（pty 会把 LF 转成 CRLF）。
> 传输二进制文件一律用 `adb push` / `adb pull`。

---

## 7. 后续的清理纪律

修好系统后又做了一轮精简，这次的规则（见 `docs/02-debloat.md`）：

1. **不删任何 `uid 1000`（`android.uid.system`）共享组的 APK**。
   创维的酷开包几乎全部共用 `android.uid.system`，
   删其中任何一个都会让**整组签名校验失效** → `com.tianci.system` 和 Aerial 一起起不来 → 变砖。
   这一组只能用 `pm disable-user` / `pm uninstall --user 0`（不删 APK）。
2. 只有**独立 uid** 的包才能删 APK（商城、支付、浏览器、卡拉OK 等，已删 8 个）。
3. 每一步先备份 `/system`（`apps.tar` 250 MB + `etc.tar` 65 MB），
   并导出 `packages.xml` + 全部系统 APK 的 md5 作为回滚清单。

---

## 8. 本次沉淀的工具

| 工具 | 作用 |
| --- | --- |
| `tools/root-run.sh` | 以完整 root 身份执行脚本（走 boot-shell 通道，不依赖 U 盘） |
| `tools/guardctl.c` | coocaa_guard 客户端（已支持 abstract socket） |
| `tools/cleanup-*.sh` | 清理工具（**已修正匹配逻辑**，见下） |
| `tools/recover-apks-from-image.sh` | 从 system.img 里提取 APK，用于取证 |
| `tools/rescue-recovery.sh` | recovery 下的救援脚本 |
| `payload/hi_boot_shell.sh` | U 盘自愈入口（静态 IP / su / Aerial / 悬空包清理） |

`cleanup-system-orphans.sh` 的匹配逻辑已修正为**两边都规范化到纯路径**：

```sh
pm list packages -f 2>/dev/null | $BB sed 's/^package://' | $BB sed 's/=.*$//' > .installed_paths
```

---

## 9. 下次再遇到卡 logo

1. 进 recovery（断电 → 插 U 盘 → 长按 Home）
2. U 盘根目录放 `update.zip`（本机用 `8H52_G3_V017.012.060_9_online.zip`）
3. 选「使用U盘或SD卡升级」→ 等 → 重启
4. 开机后 U 盘自愈脚本自动恢复 root 和桌面
5. 若电视自动 OTA 升级失败，回落到 recovery 再刷一次 V017

**永远保留 U 盘** —— 它既是救砖通道，也是 root 通道。
