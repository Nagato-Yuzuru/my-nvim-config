; extends
; jq '...'——同 after/queries/bash/injections.scm 的 zsh 版（grammar 是 bash 的
; fork，节点名一致；查询按 parser 语言分文件加载，无法共享，双份是常态——同
; after/queries/<lang>/textobjects.scm 的约定）。设计取舍与已知限制见 bash 版注释。
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
