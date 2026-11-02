# Kindle 充电限制说明

## 功能概览

Lunar Panel 的充电限制功能使用一个独立的后台控制器，将电池充电控制在 **40% 至 80%** 的周期内：电量达到或超过 80% 时请求停充；之后等到电量降至 40% 或以下，再请求恢复充电。显示面板和充电控制器是两个独立进程，关闭面板不会自动停止限充。

此功能目前针对已越狱的 Kindle Basic 2（第八代，Eanab）、固件 `5.16.2.1.1` 实现。它依赖该设备的 `bd7181x` 驱动接口；其他设备和固件不能仅凭接口同名就假定兼容。

## 控制规则

| 条件 | 行为 |
| --- | --- |
| 电量达到或超过 80% | 进入停充阶段；接入电源时请求关闭充电。 |
| 停充阶段，电量在 41% 至 79% | 继续等待；拔插电源后仍保持停充阶段。 |
| 电量降至 40% 或以下 | 进入充电阶段；接入电源时请求开启充电。 |
| 充电阶段，电量在 41% 至 79% | 保持充电阶段，直到达到上限。 |
| 启动控制器时电量在 41% 至 79% | 默认进入停充阶段，等待电量降至 40%。 |

控制器约每 **10 秒**检查一次。插入电源时，系统可能先短暂开始充电，然后控制器在下一次检查时执行停充。百分比由设备驱动提供，可能存在延迟，因此实际停充读数不保证精确等于 80%。

拔掉电源后，如果控制器之前关闭过充电，它会请求恢复充电开关，但在当前控制器进程内保留充电阶段。重新接入电源时，控制器依据该阶段重新决定是否停充。**阶段只保存在运行中的进程内**；停止或重新启动控制器后会重新初始化，不能跨重启保留此前的充电阶段。

## 实现方式

### 依据从哪里来

实现依据包括两部分：一是分析固件版本 `5.16.2.1.1` 的 Kindle 源码包中的 `bd7181x` Linux 电源驱动，二是在当前 Kindle 上检查 `sysfs` 接口并进行停充、恢复充电测试。

分析时使用了用户提供的 `Kindle_src_5.16.2.1.1_4097490002.tar.gz`，其文件名对应当前设备固件版本；该源码包不包含在本项目仓库中。检查路径如下：

1. 从外层包提取 `gplrelease/linux-3.10.53.tar.gz`。
2. 从内核源码包提取 `drivers/power/bd7181x-power.c`。文件头标注其为 ROHM BD71815/BD71817 充电驱动，采用 GPL 许可。
3. 将提取的驱动文件与之前分析时保留的副本计算 SHA-256：两者均为 `9f261cb92861e88c4667ac7e2bcc8e4f9a51644bd2a32ed7e383d597fa7f41ab`，内容一致。

这是**阅读源码并结合实机验证**，不是对固件二进制进行反编译。该源码包由用户提供，当前记录未保留官方下载地址或官方校验值；包名与文件一致性已核对，但未独立验证下载来源或包内源码与设备运行的内核二进制逐字对应。

### 如何发现充电开关

源码中 `bd7181x_sysfs_set_charging` 处理对 `charging` 属性的写入：写入 `1` 时设置 `BD7181X_REG_CHG_SET1` 的 `CHG_EN` 位，写入 `0` 时清除此位；`DEVICE_ATTR(charging, ...)` 将读写函数注册为设备属性，写权限限定为所有者。对应逻辑可概括为：

```c
if (val == 1)
    bd7181x_set_bits(pwr->mfd, BD7181X_REG_CHG_SET1, CHG_EN);
else
    bd7181x_clear_bits(pwr->mfd, BD7181X_REG_CHG_SET1, CHG_EN);
```

同一驱动的 `bd7181x_sysfs_show_charging` 将读数计算为“充电器在线，并且 `CHG_EN` 位置位”。因此，拔掉电源时读到 `0`，并不能证明寄存器中的充电使能位已关闭。这也是控制器同时读取外部电源状态的原因。

驱动的写入函数在解析无效输入时仍返回写入字节数，且没有检查 `bd7181x_set_bits` / `bd7181x_clear_bits` 的返回值。因此，写入调用成功不能单独证明底层寄存器修改成功。当前控制器只写入 `0` 或 `1`，并在接电状态下回读 `charging`；这个回读也不能单独证明实际充电电流或硬件供电路径。

在 Kindle 上，确认了对应的 `bd7181x_bat/charging` 属性和电源状态接口，并在接入电源的高电量条件下，测试写入 `0` 后停充、写入 `1` 后请求恢复。项目中的 [`charge-probe.sh`](charge-probe.sh) 保留了这类实机探测的步骤；它会实际操作充电开关，不是只读诊断脚本。源码分析与上述实测共同支持当前设备的实现，但不证明其他型号或固件使用相同语义。

仅凭这两个属性函数无法确定设备断电或重启后寄存器的最终状态。当前控制器不随开机自动启动，也不持久化充电阶段；退出和看护进程会尝试恢复充电，但无法保证断电或系统故障后一定完成恢复。

### 当前控制器

控制逻辑位于 [`LunarPanel/charge-control.sh`](LunarPanel/charge-control.sh)。它通过设备的 Linux `sysfs` 电源接口读取状态并请求修改充电开关：

| 接口 | 用途 |
| --- | --- |
| `/sys/class/power_supply/bd7181x_bat/capacity` | 读取电池百分比。 |
| `/sys/class/power_supply/bd7181x_ac/online` | 读取外部电源是否接入。 |
| `/sys/class/power_supply/bd7181x_bat/charging` | 读取充电状态，并通过写入 `0` 或 `1` 请求停充或恢复充电。 |

启动时，脚本会将自身复制到 `/tmp/lunarpanel-charge/`，然后启动监控进程和独立看护进程。监控进程定期更新心跳；看护进程约每 15 秒检查一次，发现监控进程消失或心跳超时（超过 180 秒，或时间异常超前）时，会尝试恢复充电并记录日志。主动停止控制器时也会尝试恢复充电。

运行状态文件位于 `/tmp/lunarpanel-charge/`，事件日志位于 Kindle 的 `/mnt/us/extensions/LunarPanel/charge.log`。更新原脚本不会替换已经运行的临时脚本副本，因此更新后必须停止并重新启动控制器。

## 好处与边界

- 对长期插电的设备，限制高电量停留时间可能有助于减轻锂电池老化；实际效果受电池、温度和使用条件影响，不能保证具体寿命提升。
- 上下限形成滞回区间，避免在某个单一阈值附近频繁启停充电。
- 充电控制不依赖电脑持续连接，也不依赖网络；但依赖 Kindle 持续运行控制器和看护进程。
- 停充不会强制电池放电，也不能保证插电时电量会快速下降。`Discharging` 表示设备报告电池放电，不能单独说明外部电源和电池各承担多少负载。
- 未接外部电源时，`charging` 读数可能为 `0`，不能据此单独判断充电开关是否被禁用。电量、状态和电流读数也可能延迟。
- 这不是电池硬件保护机制的替代品。休眠、断电、强制重启、系统故障或无法写入接口时，不保证控制器或看护进程能及时执行操作。控制器不会开机自动启动。

## 安装和启用

**前提：** Kindle 已越狱并安装 KUAL，型号和驱动与上述已验证设备一致。项目不包含越狱或 KUAL 安装程序。

1. 用 USB 将 Kindle 连接电脑。将项目中的整个 `LunarPanel/` 目录复制到 Kindle 存储盘的 `extensions/LunarPanel/`。如果目录已存在，先备份并检查，避免覆盖已有设置、日程和句库。
2. 安全弹出 Kindle 并断开数据线，在 KUAL 打开 **Lunar Panel**。如果没有对应菜单，检查目录是否为 `extensions/LunarPanel/`，并重新打开 KUAL。
3. 选择 **Check charge control**，之后可在 Kindle 存储盘的 `extensions/LunarPanel/charge-check.txt` 检查电源接口信息。其他设备需要先确认驱动和接口的实际语义。
4. 连接充电器，在 KUAL 选择 **Start charge limit 40-80**。该操作不要求先启动显示面板。
5. 查看 `extensions/LunarPanel/charge.log`，确认出现 `charge limiter started`。当需要执行状态切换时，日志会记录 `charging disabled at ...%` 或 `charging enabled at ...%`。

停止限充并请求恢复充电：在 KUAL 选择 **Stop charge limit and enable charging**。这与 **Stop panel** 是不同操作。

## 更新

已有 Lunar Panel 且只更新充电控制器时：

1. 在 KUAL 选择 **Stop charge limit and enable charging**，等待控制器停止。此操作会请求恢复充电，更新期间可能开始充电。
2. 连接电脑并备份 Kindle 上的 `extensions/LunarPanel/charge-control.sh`。将项目中最新的 `LunarPanel/charge-control.sh` 复制到同一位置。仅更新此脚本不需要覆盖日程、句库、缓存或其他面板文件。
3. 安全弹出 Kindle、断开数据线。若仍需限充，在 KUAL 选择 **Start charge limit 40-80**，然后查看 `charge.log` 确认新控制器启动及所需的状态变化。
4. 如果还要更新 KUAL 菜单或面板其他功能，另行核对并更新相应文件；不要无条件覆盖整个现有目录。

如果设备重启后要重新启用限充，也需在 KUAL 再次选择 **Start charge limit 40-80**。如果需要优先恢复普通充电，可先选择 **Stop charge limit and enable charging**，再检查充电状态。

## 检查与验证

在 Kindle 的 SSH 终端中，可只读查看当前状态：

```sh
cat /sys/class/power_supply/bd7181x_bat/capacity
cat /sys/class/power_supply/bd7181x_ac/online
cat /sys/class/power_supply/bd7181x_bat/charging
cat /sys/class/power_supply/bd7181x_bat/status
tail -n 30 /mnt/us/extensions/LunarPanel/charge.log
```

日志中的 `watchdog: monitor stopped or timed out; restoring charging` 表示看护进程检测到异常并尝试恢复充电；`ERROR` 行表示操作失败，需要结合设备状态排查。

在项目目录运行 `python test-charge-policy.py` 可测试不同电量、充电阶段和插拔电源条件下的判定逻辑。该测试依赖 Python 和脚本内指定的 Git Bash 路径，不会操作 Kindle 硬件。

已在当前设备上验证高电量停充、手动停止后请求恢复，以及监控进程被强制终止后看护进程请求恢复。**从停充放电至 40% 以下并自动续充的完整周期尚未实机验证**；策略测试通过不能替代该验证。
