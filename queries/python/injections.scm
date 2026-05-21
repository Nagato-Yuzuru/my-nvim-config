;; extends

;; # language=<lang>
;; var = "..."   /   var = """..."""
((comment) @injection.language
 .
 (expression_statement
   (assignment
     right: (string (string_content) @injection.content)))
 (#lua-match? @injection.language "language=")
 (#gsub! @injection.language ".*language=%s*" "")
 (#gsub! @injection.language "[^%w_%-].*" ""))

;; # language=<lang>
;; "..."   (bare string expression)
((comment) @injection.language
 .
 (expression_statement (string (string_content) @injection.content))
 (#lua-match? @injection.language "language=")
 (#gsub! @injection.language ".*language=%s*" "")
 (#gsub! @injection.language "[^%w_%-].*" ""))
