;; extends

; Go's upstream textobjects.scm does not capture switch/select as
; @conditional, so ]i/[i and ai/ii miss them. Fill the gap here.

(expression_switch_statement) @conditional.outer
(type_switch_statement)       @conditional.outer
(select_statement)            @conditional.outer

(expression_case)    @conditional.inner
(type_case)          @conditional.inner
(default_case)       @conditional.inner
(communication_case) @conditional.inner
