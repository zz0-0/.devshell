# DevShell flake

## 入口

```bash
nix flake check
./scripts/check-templates.sh     # 模板冒烟，约 15 秒
```

## 接口

`lib.<system>.<lang>` 和 `templates/<lang>` 是公共接口。改名、改签名、改模板结构都属于破坏性变更。

项目通过 `github:zz0-0/devshell` 消费这个 flake，不能让项目指向本地路径。

## 注意

这个仓库没有 CI。push 前由 `.githooks/pre-push` 跑上面两条；新 clone 先跑 `./scripts/setup.sh`。

测模板必须用 `--override-input devshell path:.` 指向本地，否则测的是 GitHub 上那份。`check-templates.sh` 已经这样做了；手跑时别忘了。
