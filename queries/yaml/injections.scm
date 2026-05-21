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
