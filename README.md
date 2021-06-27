# Ehcoo
一个 `ehco` 配置便捷脚本

## 优点
- [x] 简单配置 `ehco` 隧道
- [x] 支持开机自启
- [x] 支持中转机器 
- [x] 支持落地机器

## 已知问题(计划在一周内修复)
- 无法增加多台中转机器
- 可能由于端口占用无法启动
- 无法在国内机器上使用（由于 `raw.githubusercontent.com`被墙）

## 兼容性
支持 `CentOS` `Ubuntu` `Debian` 等 `Linux` 系统的所有版本

## 使用
```shell
wget -O ehco.sh https://raw.githubusercontent.com/missuo/Ehcoo/main/ehco.sh && bash ehco.sh
```
## 感谢
- 感谢 [echo](https://github.com/Ehco1996/ehco) 所有开发者的贡献
- 感谢 [Jack](https://github.com/Jackxun123) 提供的 `jq` 处理 `JSON` 的方案

## 反馈
你可以提出ISSUES。
