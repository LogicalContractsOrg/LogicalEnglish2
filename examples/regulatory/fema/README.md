# A flood insurance policy, drafted by the LE Contract Assistant

*Kind: example · Audience: insurance and legal readers · Status: an experiment of 4 October 2026*

This folder records an experiment. We gave the **LE Contract Assistant**, a
tool that writes the first draft of a Logical English program from a contract,
a real insurance policy and a set of test claims, and asked it for its most
thorough work. The program it delivered is here, with the one rule we wrote by
hand afterwards, and with what the run left undone.

The policy is the **Standard Flood Insurance Policy, Dwelling Form**, of the
United States National Flood Insurance Program (FEMA form F-122, October 2021
edition, about 13,000 words). The policy schedules and the claims are
**synthetic**: they were written to test the policy, and describe no real
person or property. Nothing here is advice, and the program is provided "as
is", without warranty.

## Try it

- Open [fema_dwelling.le](fema_dwelling.le?scenario=SYN-01-C5&query=payment) and press **Query**. The answer is *we will pay 3500 for claim SYN-01-C5*: $9,000 of jewellery capped at $2,500 (Article III.B.8), plus a $3,000 sofa, less the $2,000 contents deductible. Click the answer: each step of the explanation shows the clause it rests on.
- Open [the claims desk](fema_dwelling.le?view=claims%20desk&scenario=SYN-01-C5), a screen the program declares for the person who handles claims (a *view*): the facts of the claim in groups, the amount, the clauses cited, the three stages of the decision, and **Find the smallest changes**, which lists the changes to the facts that would change the amount.

## The files

| File | What it is |
|---|---|
| `fema_dwelling.le` | the program: the one the assistant delivered, with the changes of *Written by hand* below |
| `fema_F-122-Dwelling-SFIP_2021.pdf` | the policy, as published at <https://www.fema.gov/sites/default/files/documents/fema_F-122-Dwelling-SFIP_2021.pdf> |
| `wording-fema_f-122-dwelling-sfip_2021.md` | the policy's text as the assistant read it, converted from that PDF. The program's quotations are checked against this file |
| `fema_F-122-Dwelling-SFIP_2021.md` | an earlier conversion of the same PDF, by hand, kept for reference |
| `schedules.json` | three policy schedules (limits, deductibles, policy period, property) |
| `claims.json`, `expected_outcomes.json` | seventeen claims, and the outcome an adjuster would record for each, with the clauses used |
| `run/delivered.le.txt` | the program exactly as the assistant delivered it (a `.txt`, so that the test suites do not run it) |
| `run/fixes.diff` | the differences between that program and `fema_dwelling.le` |
| `run/job.log`, `run/scores.json`, `run/ledger.md`, `run/vocabulary.md` | the run's log, its scores, its closing report, and the vocabulary its models agreed on |

## The steps

1. On the Contract Assistant's page, the policy was given by its **web address**. The server fetched the PDF and turned it into text, reading each two-column page one column at a time so that every sentence stayed whole.
2. `schedules.json` was given as the schedule, and `claims.json` with `expected_outcomes.json` as the cases. The assistant joined the two case files on the claim reference (`claimRef`), so that each recorded outcome became a **test**: an expected answer that the program must give.
3. Models: OpenAI's **GPT 5.6 Sol** to write, **GPT 5.6 Terra** as the judge that merges the vocabulary samples, and **Qwen 3.8** (`Qwen/Qwen3.8-2.4T-A95B`, a model whose weights are published, served by Together AI) to write every other draft.
4. Effort: **Thorough**. Five samples of the vocabulary, three competing drafts, eight probing cases against the winner, two hours.
5. The assistant kept 13 claims to draft with and held back the last 4 (SYN-03-C2 to SYN-03-C5), unseen, to score each finished draft.

The run (job `caj_61ad03bd-c006-11f1-bff6-6ecba305ecba`) took 2 hours 2 minutes. The estimate of its cost, made before it started, was at most $36.95.

## The result

| Draft | Written by | Result |
|---|---|---|
| 1 — **delivered** | GPT 5.6 Sol | no errors; all 19 tests on the 13 claims pass; 22 of the 28 expectations on the 4 unseen claims |
| 2 | Qwen 3.8 | no errors; 18 of 26 tests; its unseen claims were not scored (see below) |
| 3 | GPT 5.6 Sol | cut short: our OpenAI credit ran out during the run |

The delivered program has 2,241 lines and 128 rules that each name the
article they encode and quote it (`rule special_category_cap with provenance
the policy at article III.B.8, confer "We will pay no more than $2,500 for
any one loss":`). Every quotation was checked against the policy's text. The
rules are grouped in three sections: *applicability* (does the policy apply),
*question* (is the claim covered), *remedy* (what is paid). Its header lists
the parts of the policy it leaves out.

Not done in this run: the probing cases, the check of the wording put in other
words, and the clause-by-clause report of what the program covers, all
skipped because the two-hour budget was spent; and the scoring of draft 2 on
the unseen claims, because the OpenAI credit ran out.

## Written by hand

Two of the four unseen claims were decided wrongly, and the program's own
header says why: it lists "detached-garage sublimits" and "the closed
basement-property list" among its known simplifications.

- **The detached garage (claim SYN-03-C3).** We added the rule
  `detached_garage_amount`, citing Article III.A.3: a detached garage is
  covered up to 10 percent of the building limit. The claim now pays $11,000,
  as recorded (10% of $120,000 is $12,000, less the $1,000 deductible).
- **The basement (claim SYN-03-C2)** stays open. The recorded outcome, $6,400,
  needs the closed lists of what a basement policy covers (Articles III.A.8 and
  III.B.5), which the program does not encode; it pays $4,400. The three
  expectations the assistant wrote for this claim are kept in the file as
  comments, under a note that says why, so that the test suites record only
  what the program actually decides.

With these changes every test in `fema_dwelling.le` passes (44), and the
verifier reports nothing.

