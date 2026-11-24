# Step 0 of the L4 plan: the promissory note both ways

Step 0 of the design notes `l4.md` (the author's working papers, not published) §8 decides
which reading a contract of L4 is translated into by default. The test case
is L4's promissory note (`jl4/examples/legal/promissory-note.l4` of
`smucclaw/l4-ide`, Apache 2.0): a loan repaid in twelve instalments, where
each payment starts the same obligation again for what is still owed. Both
twins here were written by hand, the way the translator will write them.

| File | What it is |
|---|---|
| `promissory_note.le` | the **timeless** twin (LE, `prolog` target): the note read over a finished history of payments |
| `promissory_note_lps.le` | the **LPS** twin (LE for LPS): the note run forward in time by LPS2 |
| `promissory_note_lib.le`, `deontic_history.le` | the timeless twin written with the draft library of `../lib_draft/` |
| `promissory_note_traces.l4` | the L4 note with its two traces and 18 more, written to pin down how L4 treats deadlines |
| `promissory_note_traces.oracle.json` | what L4's evaluator answered for every directive of that file |
| `check_lps.py` | runs the LPS twin once per history and compares its final state with L4's answer |

## How to run

From `/work` (LE2), with LPS2 at `/lps2`:

```sh
./myswipl.sh -g "use_module(le_kbs), runTestsFor('migration/l4/step0/promissory_note.le', R), print_test_result(R), halt."
python3 migration/l4/step0/check_lps.py /lps2 /work
node migration/l4/spike/l4run.mjs migration/l4/step0/promissory_note_traces.l4
```

## Results

| Twin | Histories | Agrees with L4 | Time |
|---|---|---|---|
| timeless (`promissory_note.le`) | 20 (L4's two, and 18 more) | **40 of 40** answers | 14 s |
| LPS (`promissory_note_lps.le`) | the same 20 | **20 of 20** final states | 26 s (20 runs of 510 days) |
| timeless with the draft library | the same 20 | 38 of 40 (the twelve payments time out); 34 of 40 with the library's templates memorable | 4 min |

The 18 extra histories cover a payment on its deadline and one day late, a
short payment, two instalments paid at once, everything paid at once, the
penalty paid in time and one day late, everything owed paid after the
penalty was missed, and time passing with no payment at all.

## What L4 does, found by running it

1. **A missed deadline is noticed only when something next happens.** The
   evaluator moves to the `LEST` obligation when the next event arrives
   after the deadline — a payment, or a `WAIT UNTIL` — and not when the
   deadline passes. The `LEST` obligation starts at that event, and its own
   deadline counts from there. `WAIT UNTIL 500` alone takes one step, not
   two: the penalty obligation is still open at day 500 although its own
   deadline passed long before.
2. **The event that reveals the missed deadline is used up.** A payment of
   the penalty amount that arrives after the first deadline starts the
   penalty obligation, and does not pay it (history `c_penalty_amount_late`).
3. **A deadline includes its last day**, and counts from the day the
   obligation started, so the note's deadlines drift as payments are made
   early (the next instalment's deadline is 71 days after the first
   payment, not 71 days after the loan started).
4. **Paying the penalty ends the note.** The note's authors wrote
   `HENCE FULFILLED` after the penalty obligation: once the penalty
   instalment is paid, nothing more is owed, whatever the rest of the
   schedule. This is what the program says; it is probably not what the
   authors meant, and the L4 team should be told, with point 3.

## Two things LE needed, since fixed

- **LE's check against endless loops** (`reasoner.pl`) refused a condition
  that merely *matched* a condition already being proved, rather than one
  that is the same. The timeless twin therefore fixed each date first, with
  the extra sentence `an obligation can start on *a date*`. The check now
  refuses only the same condition (a variant), and the twin runs without
  that sentence (40 of 40).
- **Remembering answers (`; memorable`) and that check did not mix**: an
  answer cut short by the loop check was remembered as complete. Remembered
  answers are now worked out to a fixpoint. The draft library gives the
  right answers since, but still takes longer than the test runner allows on
  the twelve payments (38 of 40; `../lib_draft/README.md`).

## The gate: a lawyer reads both twins

*Role-played: a solicitor who drafts consumer credit agreements, reads
Logical English for the first time, and is asked which twin they would sign
off as a faithful statement of the note.*

> The LPS version reads like the note. Each clause is one sentence: when the
> borrower pays an instalment in time, the rest is owed in instalments; when
> the borrower pays late, a penalty instalment is owed; when the penalty is
> paid in time, the note is fulfilled. I can put my finger on the sentence
> for each clause of the paper note, and the "noticed only at the next
> payment" rule is visible as the word *when*. I would sign it off after
> checking the arithmetic.
>
> The timeless version is correct, and I like that it answers the question
> I am usually asked — "given these payments, where do we stand?" — with an
> explanation. But a third of it is not about the note. "An obligation can
> start on a date", "something happens on a date", and the two long "it is
> not the case that … an earlier day" conditions are about how to read a
> history, and they are repeated for each kind of obligation. I would not
> want to explain those to a client, and I would not trust myself to check
> them.

**Decision.** The gate of §8 step 0 required three things of the timeless
twin: that it reproduce L4's traces (it reproduces all 20 histories), that
it read no worse than the LPS twin, and that it need no more than the one
library. It fails the second, and the library that would remove its
repetitions does not yet run acceptably on LE's engine (the third). So:

- **L4's contracts are translated into LE for LPS by default**, run by LPS2.
- **The timeless reading is kept as the history view** — "given these
  events, who owes what, and why" — written from the same model, for the
  programs whose histories are what their users ask about.
- **L4's rules (everything that is not a contract) stay in timeless LE**, as
  §3 of the plan says; nothing in this step changes that.

The decision is worth revisiting if LE's loop check is changed to refuse
only the same condition: the timeless twin would then lose its extra
sentences, and the library would become usable.
