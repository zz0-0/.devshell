# film

> 一个根：`index.html` 是正片。别的构图放 `compositions/`；历史件进 `legacy/`。

- `index.html`：正片根。`data-composition-id` / `data-duration` / `data-width` / `data-height` / `data-fps` 写在 `#root` 上。
- `compositions/`：子构图。根目录多一个带 `data-composition-id` 的 html，`hyperframes check` 会报 `multiple_root_compositions`。
- `assets/`：媒体与字体。CJK 必须 `@font-face` 声明（`assets/fonts.css`），只靠系统字体换机器就掉字。
- `legacy/`：试验件，不进渲染。
- `.hyperframes/`：渲染缓存，不进 git。

第一次：`npx hyperframes init .` 或 `npx hyperframes preview`。
