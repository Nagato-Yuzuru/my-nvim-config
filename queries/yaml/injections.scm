;; extends

;; # language=<lang>
;; key: |
;;   ...multi-line content...
((comment) @injection.language
 .
 (block_mapping_pair
   value: (block_node (block_scalar) @injection.content))
 (#lua-match? @injection.language "language=")
 (#gsub! @injection.language ".*language=%s*" "")
 (#gsub! @injection.language "[^%w_%-].*" ""))

;; # language=<lang>
;; key: "..."  (single-line string)
((comment) @injection.language
 .
 (block_mapping_pair
   value: (flow_node (plain_scalar) @injection.content))
 (#lua-match? @injection.language "language=")
 (#gsub! @injection.language ".*language=%s*" "")
 (#gsub! @injection.language "[^%w_%-].*" ""))

;; ── Prometheus / Loki 规则文件:`expr:` 的值注入 promql 高亮 ──
;; 覆盖 block scalar(expr: |）与单行 plain 两种写法;引号字符串故意不注入——把引号
;; 一起喂给 promql parser 反而整体解析失败,不如留给 yaml 原色(中性无害)。任意 yaml
;; 的 `expr:` 都会命中:非 prometheus 场景(极少)只是误着色,无害。promql parser 的
;; 安装见 plugins/treesitter.lua 的 ensure_install。
((block_mapping_pair
   key: (flow_node) @_expr_key
   value: (block_node (block_scalar) @injection.content))
 (#eq? @_expr_key "expr")
 (#set! injection.language "promql"))

((block_mapping_pair
   key: (flow_node) @_expr_key
   value: (flow_node (plain_scalar) @injection.content))
 (#eq? @_expr_key "expr")
 (#set! injection.language "promql"))
