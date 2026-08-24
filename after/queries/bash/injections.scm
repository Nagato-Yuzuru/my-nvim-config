; extends
; jq '...'——shell 管道里的 jq 程序注入 jq 高亮/结构（同 yaml→promql 注入先例）。
; 只取单引号 raw_string：双引号里 shell 先展开 $var，与 jq 自己的 $var 撞车，
; 注入高亮会误导。#offset! 剥掉两侧引号。
; 已知限制：命中 jq 命令的**每个** raw_string 参数——`--arg k 'v'` 的 'v' 也会
; 被当 jq 高亮（tree-sitter 锚点表达不了"第一个 raw_string"，值通常是纯标量，误
; 伤可忽略）。
((command
  name: (command_name) @_cmd
  argument: (raw_string) @injection.content)
  (#eq? @_cmd "jq")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "jq"))

; awk '...'——同款按命令名注入（gawk 一并；设计取舍同上）。
((command
  name: (command_name) @_cmd
  argument: (raw_string) @injection.content)
  (#any-of? @_cmd "awk" "gawk")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "awk"))
