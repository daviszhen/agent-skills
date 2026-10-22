# digitalitem · Agent Skills（中文）

面向**普通用户**的 agent skill 精选集：写文档、做演示、排计划、跑小生意的人能用上的，而不只是工程师。

**77 个包**，全部有明确许可（MIT / Apache-2.0 / CC0），每个是一个 `SKILL.md` 加参考资料。

→ 站点（113 个条目、搜索、下载）：https://digitalitem.online/zh/skills/
→ English: [README.md](README.md)

## 目录结构

```text
skills/<slug>/SKILL.md      # 指令本体
skills/<slug>/README.md     # 说明
skills/<slug>/LICENSE       # 上游许可
catalog.json                # 全部条目的元数据
NOTICE.md                   # 每个包的上游来源与许可
```

## 安装

```bash
git clone https://github.com/<you>/agent-skills.git
cp -r agent-skills/skills/* ~/.claude/skills/
```

## 许可

- 每个 skill 保留**上游许可**，逐条列在 [NOTICE.md](NOTICE.md)；
- 本仓库自身文件（README、catalog、NOTICE）采用 **MIT**；
- 这里是镜像，上游始终是最终来源。

## 更新

站点是唯一事实来源；本仓库由同一份清单重新生成，包内容与站点 zip 一致。
