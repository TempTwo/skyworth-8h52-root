# 恢复 / 救砖

本方案**没有刷机、没有改 boot 分区**，最坏情况也只是"桌面不对"，系统一定能救回来。

## 0. 手上的牌

| 通道 | 条件 | 能力 |
| --- | --- | --- |
| ADB | 电视能开机 | shell 权限，可改 `/data/local/tmp`、触发 `boot-shell` |
| `/system/xbin/su` | 已 Root | uid 0（能力有限，见 docs/01） |
| U 盘 + `boot-shell` | init 能跑到 `dev.bootcomplete=1` | 完整 root |
| 工厂菜单 `com.coocaa.factory` | 遥控器组合键 | 恢复出厂 |

## 1. 桌面进不去 / 黑屏

1. ADB 连上后直接拉起桌面：

```sh
./tools/tv-adb.sh shell 'am start -n com.oversea.aslauncher/.ui.main.MainActivity'
```

2. 还是不行就换回酷开桌面（配置在 `/system` 里，需要 root）：

```sh
./tools/run-task.sh ./payload/tasks/90_restore_stock.sh
```

3. 恢复出厂（**会清空所有数据，包括 root**）：

遥控器按 `MENU` 或进入"设置 → 恢复出厂设置"；或用工厂菜单里的 reset 项。

## 2. 恢复原厂桌面

```sh
./tools/run-task.sh ./payload/tasks/90_restore_stock.sh
```

该脚本会：

* 用 `/data/local/tmp/general_config.xml.bak4` 覆盖回原配置；
* `pm enable` 恢复 `com.tianci.movieplatform` / `com.tianci.appstore` / `com.coocaa.skycast.tool` 等；
* 把 `persist.service.homepage.*` 指回 `com.tianci.movieplatform`；
* 删除 `/system/etc/hosts` 里我们加的屏蔽行。

## 3. 彻底去掉 root

```sh
adb shell 'su -c "rm -f /system/xbin/su"'   # 需要可写 /system
```

或用 `payload/tasks/90_restore_stock.sh` 里的 `REMOVE_SU=1` 分支。

## 4. Root 再次失效（比如 OTA 覆盖了 /system）

1. 重新做一次 U 盘（`tools/make-usb.sh`）；
2. 插电视，触发：

```sh
./tools/tv-adb.sh shell 'setprop ctl.start boot-shell'
```

3. 验证：

```sh
./tools/tv-adb.sh shell '/system/xbin/su -c id'
```

## 5. 关键文件位置

| 文件 | 作用 |
| --- | --- |
| `/system/xbin/su` | setuid root 二进制 |
| `/system/pcfg/8H52_G3/config/general_config.xml` | 厂商主配置（桌面/广告开关） |
| `/data/ccos/general_config.xml` | 厂商运行时配置副本 |
| `/system/etc/hosts` | 我们加的域名屏蔽 |
| `/data/local/tmp/boot_task.log` | 每次 root 任务日志 |
| `/data/local/tmp/general_config.xml.bak4` | 配置备份 |
| `/data/local/tmp/general_config.xml.orig` | 最初原厂配置备份 |
| `/data/local/tmp/pending_task.sh` | 待执行的 root 任务 |
