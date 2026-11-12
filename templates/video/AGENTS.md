# <项目名>

<一句话：这个片子给谁看、讲什么、多长、哪个平台>

## 入口

    ./check.sh                   # 仓库门：环境 / 文档 / 上屏 / 交付
    ./scripts/stills.sh          # 静帧门：按剧本时间点抽帧；看完 --approve
    ./scripts/pre-render.sh      # 渲前门：上屏数字 + hyperframes check + 静帧批准
    ./scripts/check-qc.sh [mp4]  # 画面门：黑帧 / 静止 / 平帧 / 响度
    ./scripts/check-delivery.sh  # 交付门：scripts/deliver.manifest

设计 `content/FACTS.md` + `content/STYLE.md` · 过程 `TRACE.md`（日志，只追加）

## 闸门

- 渲前 `pre-render` 绿；交付前 `check-qc` + `check-delivery` 绿；发布由用户点头。
- 事实 / 数字回 `content/FACTS.md`；示例数字标「示意」。

## 不要

- 不写疗效 / 医疗建议（有健康主张时）。
- 不用未授权的音乐、字体、图片、商标。
