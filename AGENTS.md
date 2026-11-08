# DevShell flake

## 入口

```bash
./scripts/check.sh               # 默认：eval 全部 + 接口 + 只验改到的模板（钩子跑的是它）
./scripts/check.sh --all         # 全验：每个模板真的进一次 devShell。发布前跑
nix run .#new -- <lang> <dir>    # 起新项目
```

## 接口

`lib.<system>.<lang>` 和 `templates/<lang>` 是公共接口。改名、改签名、改模板结构都属于破坏性变更。

项目通过 `github:zz0-0/devshell` 消费这个 flake，不能让项目指向本地路径。

## 注意

这个仓库没有 CI。push 前由 `.githooks/pre-push` 跑上面这几条；新 clone 先跑 `./scripts/setup.sh`。

测模板必须用 `--override-input devshell path:.` 指向本地，否则测的是 GitHub 上那份。`check-templates.sh` 已经这样做了；手跑时别忘了。
