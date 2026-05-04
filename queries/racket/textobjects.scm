; nvim-treesitter-textobjects上游对Lisp系只有fennel,没有racket/scheme——
; 没这个文件,]f/[f/]a/[a全部捕获0个节点。
;
; @function.outer:覆盖racket常见定义关键字——define / define-syntax* /
; define/contract / define/public 等(define-* 和 define/* 全收),以及lambda/λ/
; case-lambda。
;
; @parameter.outer:任何list第一个symbol之后的子节点。在(foo a b c)里a/b/c都
; 算parameter,在(define (f x) body)里(f x)和body也算——足够支持]a/[a跳转。
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
