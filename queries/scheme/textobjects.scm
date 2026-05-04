; 见 queries/racket/textobjects.scm 的注释。scheme grammar节点名和racket一致,
; 但scheme关键字面更窄——主要是R5RS/R7RS的define / define-syntax / define-
; record-type / lambda / case-lambda。Steel/Guile扩展的define-类宏靠regex兜住。
((list
   .
   "("
   (symbol) @_kw
   (#match? @_kw "^(define([-/].*)?|defmacro|defun|defn|defn-)$"))
 @function.outer)

((list
   .
   "("
   (symbol) @_kw
   (#match? @_kw "^(lambda|λ|case-lambda)$"))
 @function.outer)

(list
  .
  "("
  (symbol)
  (_) @parameter.outer)
