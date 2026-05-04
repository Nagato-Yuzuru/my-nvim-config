; nvim-paredit form捕获(racket)。上游queries/只有scheme/clojure/commonlisp/
; fennel/janet_simple,没有racket——少了这个文件,.rkt里所有slurp/barf/wrap会
; 静默no-op。racket grammar的form节点名和scheme一致,vector/byte_string略有差。
(list) @form
(vector) @form
(byte_string) @form

(comment) @comment
(block_comment) @comment
