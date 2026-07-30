; extends
;
; 上游 nvim-treesitter-textobjects 的 json/textobjects.scm 全文只有一行
; `(comment) @comment.outer`——json 在文本对象上是全空的（yaml 有
; @assignment，toml 有 @parameter，json 两个都没有）。这里补齐，使同一批键在
; 三种结构化格式里语义一致：
;
;   av / iv   值连键 / 值本身（子树）   @assignment.outer / .rhs
;   aa / ia   一个条目，outer 含逗号    @assignment 之外的 @parameter
;
; @assignment 部分与上游 yaml/textobjects.scm 同形（含未绑键的 lhs/inner/
; @statement.outer），避免 json 和 yaml 的 capture 语义分叉；@parameter 部分
; 照上游 toml/textobjects.scm 抄——逗号在前和在后各需一条 pattern。
;
; 键位绑定在 lua/plugins/edit/textobjects.lua。

; 键值对：整对 / 键 / 值
(pair
  key: (_) @assignment.lhs
  value: (_) @assignment.rhs) @assignment.outer @statement.outer

(pair
  key: (_) @assignment.inner)

(pair
  value: (_) @assignment.inner)

; object 成员，outer 吃掉相邻逗号
(object
  "," @parameter.outer
  .
  (pair) @parameter.inner @parameter.outer)

(object
  .
  (pair) @parameter.inner @parameter.outer
  .
  ","? @parameter.outer)

; array 元素，同上
(array
  "," @parameter.outer
  .
  (_) @parameter.inner @parameter.outer)

(array
  .
  (_) @parameter.inner @parameter.outer
  .
  ","? @parameter.outer)
