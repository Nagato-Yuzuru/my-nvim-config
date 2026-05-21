;; extends

;; -- language=<lang>
;; local var = "..." / local var = [[...]]
((comment) @injection.language
 .
 (variable_declaration
   (assignment_statement
     (expression_list
       (string content: (string_content) @injection.content))))
 (#lua-match? @injection.language "language=")
 (#gsub! @injection.language ".*language=%s*" "")
 (#gsub! @injection.language "[^%w_%-].*" ""))

;; -- language=<lang>
;; var = "..." / var = [[...]]  (no `local`)
((comment) @injection.language
 .
 (assignment_statement
   (expression_list
     (string content: (string_content) @injection.content)))
 (#lua-match? @injection.language "language=")
 (#gsub! @injection.language ".*language=%s*" "")
 (#gsub! @injection.language "[^%w_%-].*" ""))
