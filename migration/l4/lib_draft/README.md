# Draft: `lib/deontic_history.le`

A first cut of the library of the design notes `l4.md` (the author's working papers, not published)
§4.1: obligations read over a finished history. The program says when each
obligation starts, its deadline and what meets it; the library says how each
one ends — met, missed, or still pending. An obligation is written as a
sentence of the program's (`the obligation that the borrower pays an
instalment on a debt of 27077.49 starts on 2025-02-04`), so a contract with
parameters needs no numbering.

Status (29 September 2026, step 3): **not moved to LE2**. LE's loop check
and remembered answers (the plan's §7, traps 6 and 7) have been fixed in
LE2's `reasoner.pl`, and the library now gives the right answers. It still
reaches only 38 of 40 on step 0's histories, because the history of twelve
payments takes longer than the test runner's 30 seconds allow, and
restructuring it (the deadline check first, one negation fewer) made it
slower. The history views of step 3 (`../l4_history.pl`) therefore write the
library's four rules out for each obligation, in the obligation's own words,
instead of including the library: first-order templates, which LE runs much
faster than the library's `*a sentence*` places.
