# DevShell flake

## 入口

```bash
nix flake check
```

## 接口

`lib.<system>.<lang>` 和 `templates/<lang>` 是公共接口。改名、改签名、改模板结构都属于破坏性变更。

项目通过 `github:zz0-0/devshell` 消费这个 flake，不能让项目指向本地路径。

## 注意

这个仓库没有 CI。`nix flake check` 是唯一的自动判定；push 前必须跑过。
