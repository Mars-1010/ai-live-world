# MVP-04: 可爱外壳，灾难内核

在 PR #6 的 Godot 客户端上改表现层。后端、事件协议、轮询与去重逻辑不变。

## 三秒内看懂

- 正常：深色外框、粗黑轮廓、亮黄地毯和橘猫；减少均匀的粉彩柔和感。
- 投喂：金黄大字、巨型鱼形食物、放大的开心猫脸、跳跃和放射线。
- 暴雨：全房间冷蓝压暗、乌云、粗雨线和积水；猫先震惊再无语。
- 陨石：橙红预警与边框、坠落轨迹、单次暖色闪光、房间震动、冲击圈、烟尘。
  猫从震惊变惊慌；结束后停电、冒烟陨石坑、瘫倒猫继续存在。
- 技术 HUD 靠右且不震动。事件大字放在房间上方，绝不盖住猫脸。
- 无音频也必须成立。没有加入音效或引用任何现成猫梗图。

## 可迭代的文案与猫脸

调整 `scripts/presentation.gd` 的 `GIFT_STYLES`、`LABELS`、`ACTION_COPY` 和
`REACTION_COPY` 即可改文案。事件 ID 确定短句变体，不使用随机数。

| 效果 | 当前短句变体 | 时长 / 强度 |
| --- | --- | --- |
| food_drop | 续命成功 / 饭来！ / 还能再炫 | 1.6 秒 / 1 |
| rain | 谁把天捅漏了 / 这班没法上 / 猫都淋无语了 | 2.1 秒 / 2 |
| meteor_strike | 天塌了 / 猫生完了 / 陨石已送达 | 2.8 秒 / 3 |

`cat_reactions.gd` 用原创矢量叠层画六种脸：neutral（平静）、happy（开心）、
shocked（震惊）、annoyed（无语）、panicked（惊慌）、defeated（蔫了）。
优先级为正在播放的礼物反应，其次后端停电/低状态、雨天/打工、吃饭/睡觉。
动画结束回到当前状态对应的表情。工作、睡眠和探索的原有位置与运动提示保留。

大字使用随仓库附带的开源站酷快乐体；来源和完整 OFL 许可证见 `assets/`。
主横幅 64–86 px，最多八个字；手机预览为 384 × 216。陨石闪光只发生一次，
约 0.17 秒；震动只影响房间约 0.7 秒，HUD 与主事件横幅保持稳定。

## 确定性评审画面

完整画面与六张 `_phone.png` 小预览已提交到 `fixtures/`；不是概念图，均由当前
Godot 场景直接渲染。12 张完整画面覆盖六个基础动作、三类礼物及灾难的不同阶段。

| 必看场景 | 完整画面 | 手机预览 |
| --- | --- | --- |
| 正常 / idle | [idle](fixtures/idle.png) | [384 px](fixtures/idle_phone.png) |
| 吃饭 / 小礼物 | [food_drop](fixtures/food_drop.png) | [384 px](fixtures/food_drop_phone.png) |
| 暴雨 | [rain](fixtures/rain.png) | [384 px](fixtures/rain_phone.png) |
| 陨石冲击 | [meteor_impact](fixtures/meteor_impact.png) | [384 px](fixtures/meteor_impact_phone.png) |
| 停电后续 | [power_off_aftermath](fixtures/power_off_aftermath.png) | [384 px](fixtures/power_off_aftermath_phone.png) |
| 非礼物动作 / 打工 | [work](fixtures/work.png) | [384 px](fixtures/work_phone.png) |

复现（仓库根目录，需要图形显示，不加 `--headless`）：

```sh
godot --path godot --script res://tests/render_smoke.gd -- --output-dir=<仓库绝对路径>/godot/fixtures
```

测试帧锁定动画相位和状态。仍使用原事件队列，密集礼物会依 ID 排队；不跳过事件。
陌生人三秒盲测步骤与记录方式见 `SMOKE_TEST.md`。截图和逻辑测试只能证明实现，
不能代替真实观众对“好笑/混乱/读得懂”的判断。
