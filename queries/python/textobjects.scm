;; extends

; Python's upstream textobjects.scm does not capture PEP 634 match/case,
; so ]i/[i and ai/ii miss them. Fill the gap here.

(match_statement) @conditional.outer
(case_clause)     @conditional.inner
