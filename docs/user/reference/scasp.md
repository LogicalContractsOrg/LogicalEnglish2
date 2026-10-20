# s(CASP) on Logical English

*Kind: reference · Audience: users, developers · Status: current (2026-09-16)*

Logical English 2 can run the **same program** with one of two reasoning engines. A
reasoning engine is a piece of software that calculates the answers. The two engines
are:

- The default **Prolog** engine. This engine answers a question in the reverse
  direction through the rules (SLDNF). An interpreter that we wrote in Prolog,
  `reasoner.pl`, controls this engine.
- An **s(CASP)** engine. s(CASP) is a goal-directed form of Answer Set Programming.
  This engine also starts from the question. It calculates the complete sets of facts
  that agree with each other and in which the answer is true. These sets are the
  stable models. `library(scasp)` gives this engine. Logical English runs the library
  inside its own process. It does not call a separate program.

This document tells how the s(CASP) support operates now. For the reasons for the
design and for the list of work packages, refer to
[`sCASP_plan.md`](../../project/plans/sCASP_plan.md). This page is the companion of
the plan: it tells what the support does and how to use it. All of the engine is in
**`le_scasp.pl`**. The code that sends a question from the web page to the engine,
and the answer back, is in `classic_web_api.pl`. The screens that the user sees are
in `editor/`.

> **Why two engines?** Prolog is fast. Prolog calculates totals and counts over many
> facts. Prolog can do `prolog` goals and large collections of facts. Prolog stays the
> default. s(CASP) adds four things that Prolog does not do well:
>
> - s(CASP) can answer **with a condition instead of a value**, for example *any
>   amount over 25000*.
> - s(CASP) can find **several stable models**. These are several possible worlds in
>   which the answer is true.
> - s(CASP) can calculate **what must be true** for the answer to be true. This is
>   abduction.
> - s(CASP) **proves a negative statement**. Prolog only cannot find the positive
>   statement. Thus the s(CASP) answer has a real proof of *why* something fails.
>
> s(CASP) also gives correct answers for programs whose rules make a loop through a
> negation (non-stratified programs). For these programs, Prolog can possibly run
> without end or give an incorrect answer.

---

## Contents

- [1. Choosing the engine](#1-choosing-the-engine)
- [2. Architecture](#2-architecture)
  - [Runner (Mode A)](#runner-mode-a)
- [3. Traceability — click-to-source](#3-traceability--click-to-source)
- [4. LE construct → s(CASP) mapping](#4-le-construct--scasp-mapping)
  - [Constraints are relational, not functional](#constraints-are-relational-not-functional)
  - [DNF clause-splitting](#dnf-clause-splitting)
- [5. Answers: constraints, multiple models, abduction](#5-answers-constraints-multiple-models-abduction)
  - [Constraint / symbolic answers (§5b)](#constraint--symbolic-answers-5b)
  - [Multiple models — "possible worlds" (§5a)](#multiple-models--possible-worlds-5a)
  - [Abduction — assumption sets (§5c)](#abduction--assumption-sets-5c)
- [6. Explanations](#6-explanations)
- [7. Negation: De Morgan normalisation](#7-negation-de-morgan-normalisation)
- [8. Unsupported constructs → issues (errors)](#8-unsupported-constructs--issues-errors)
- [9. Stratification check (verifier)](#9-stratification-check-verifier)
- [10. Testing](#10-testing)
- [11. Guidance: which engine, when](#11-guidance-which-engine-when)
- [12. Current status and known limitations](#12-current-status-and-known-limitations)
  - [Forward compatibility (browser)](#forward-compatibility-browser)
- [13. Code map](#13-code-map)
- [14. Reading s(CASP) back](#14-reading-scasp-back-september-2026)

---

## 1. Choosing the engine

Three things select the engine. When they do not agree, each item in this list has
priority over the item before it:

1. **The program.** The first sentence of a program can name the engine for which you
   wrote the program: `the target language is: prolog.` or
   `the target language is: scasp.`. Other languages have their own words, for
   example `a linguagem alvo é: scasp.`. The server reads that sentence and keeps the
   result as `kb_target_language/2`. The editor uses the result to **select in
   advance** the engine in its engine menu (`editor/src/client.ts`, `res.target`).
2. **The engine menu in the editor.** The Query tab has a menu with Prolog and
   s(CASP). The editor keeps the selection in the web address as `?engine=scasp`.
   Thus, when a user sends a link to a different user, the link opens the same
   program, the same scenario, the same query and the same engine. After the user
   selects an engine, the declaration in the program does not change that selection
   (`engineUserSet`).
3. **The setting that shows or hides the engine menu** (Misc menu). Most Logical
   English programs are for Prolog. Thus the editor can hide the menu for those
   programs. The setting has two choices: "Always show engine choice" and "Show
   engine choice only for non-Prolog". The editor reads the text on the screen to
   find which engine a program declares (`detectTargetLanguage`,
   `editor/src/i18n.ts`). Thus the menu shows or stays hidden correctly. The editor
   does not have to ask the server first.

When the user selects s(CASP), the editor asks the server for `scaspQuery`, not for
the usual `answer`. The "See s(CASP)" button is adjacent to "See PROLOG". This button
asks for `getScasp`. `getScasp` shows the s(CASP) program that Logical English wrote
from the program of the user.

**Availability.** s(CASP) is an optional addition to SWI-Prolog. Such an addition is
a pack. `le_scasp_available/0` is true only when `library(scasp)` is installed. When
the pack is not installed, nothing stops with an error. Each way into the engine
stops correctly and gives the problem `scasp_engine_not_installed` in the language
of the reader. A query gives that message as its answer, and See s(CASP) shows the
message in a dialog box. The ready-made SWI-Prolog image, `swipl:latest`, does not
contain the pack. Thus the `Dockerfile` installs the pack with `pack_install(scasp)`.

---

## 2. Architecture

The two engines are **two children of the same loaded knowledge base**. The knowledge
base (KB) is the program as the system keeps it in memory. The system writes the
program of each engine from that knowledge base. One engine does not send data to
the other engine:

```
                LE source (.le)
                      │  existing parser
              loaded KB module (clauses + le_dict + le_source_info)
                     ╱                         ╲
         existing Prolog                    le_scasp.pl emitter
          reasoner.pl                     (lower_body / lower_leaf)
              │                                    │
          solve/8                        s(CASP) program text
              │                                    │  consult into a fresh unit
       proof term (success/failure)      scasp(Unit:Goal,[model,tree])
              │                                    │
      postprocess_why → JSON            le_scasp_tree_json (normaliser)
                     ╲                         ╱
                      common explanation-tree JSON
                              │
              existing explanation UI (+ model tabs, constraint answers)
```

The system does **not** give the Prolog code to s(CASP). This is important. The
Prolog code uses `is/2` and calculates totals and counts with `findall`. It also has
locations where our own Prolog interpreter controls the run. s(CASP) cannot run any
of these. Thus `le_scasp.pl` writes a new s(CASP) program from the loaded rules.

The body of a Logical English rule is a tree. The parts of the tree are `and/2`,
`or/2`, `not/1` and `le_at/3`. `le_at/3` contains a condition and records the
location in the document where the condition came from. The single conditions at the
ends of the tree are its leaves. `le_scasp.pl` removes each `le_at` container. It
translates the `and`, `or` and `not`, and it changes each leaf into s(CASP) (§4).

### Runner (Mode A)

`le_scasp_query/6` writes the new program, together with the facts of the scenario,
into a temporary file. The file starts with `:- use_module(library(scasp)).`. Then
`le_scasp_query/6` loads the file and calls
`scasp(Unit:Goal, [model(Model), tree(Tree)])`. It asks for one stable model after
the other. Three points are important:

- **Mode A only.** The rules go into a module as usual clauses. They do *not* go into
  `begin_scasp/end_scasp` units, because `scasp/2` cannot ask a question of a program
  in such a unit. The system writes the `#pred`, `#abducible` and opposite
  instructions together with the clauses. `library(scasp)` finds each of these
  instructions when the file loads, and records it.
- **The system gives names to the variables of the question before the search
  starts** (`name_bindings/3`). The reason is that s(CASP) fills the variables in
  their location. Then `findnsols/4` copies each answer out.
- **The search has a time limit and a size limit.** By default,
  `call_with_time_limit/2` stops the search after ten seconds. By default,
  `findnsols(Max, …)` collects 25 models. When the time ends, the reply is the
  `scasp_timeout` problem, together with the results that the search found before
  then.

---

## 3. Traceability — click-to-source

The system writes each step of an s(CASP) proof tree as a Logical English (LE)
sentence. When possible, the step also records the part of the document that it
came from. Thus, when you click the step, the editor highlights the rule or the
template. This is the same as when you click a step of a Prolog explanation.
`kb_pred_source/4` attaches those parts **for one full conclusion at a time**. The
part is the head of the rule that defines the conclusion. If there is no such rule,
the part is the location where the template is declared (from `le_source_info/4`).
`le_kbs:item_to_instance/3` and `canonical_string/2` write the sentence in each
step. Thus a step reads as the English of the program.

---

## 4. LE construct → s(CASP) mapping

`lower_body/5` and `lower_leaf/3` translate each construct:

| LE construct | s(CASP) lowering |
|---|---|
| Rule `H if B` | `H :- B.` (The system changes an `or`, written `;`, in the body into separate rules. Refer to the subsection below.) |
| `and` / `or` | `,` / `;` — then the system changes each `;` into separate clauses |
| `it is not the case that G`, `unless C` | `not G` (negation as failure: the condition is false when the system cannot prove it). De Morgan's laws move the negation inwards (§7) |
| `; opposite: T` | classical negation `-p(…)`. Classical negation states the opposite directly. The system writes each rule, fact and condition of the opposite form as `-p(…)`, and its words as `#pred -p(…) :: '…'`. The global constraint `false :- p(X), -p(X).` connects the two, because nothing can be both (`opposite_map/2`, `to_classical/2`, `opposite_constraints/2`) |
| `; assumable` / `; unknown` | `#abducible p(…).` Each model comes back with the set of facts that it had to assume (`abducible_directive/2`). The system cannot assume an element of a scenario (`; undefined`) |
| `it must not be true that …` ([language.md](language.md) §3.3) | the global constraint `false :- Conditions.` (`kb_constraint_clauses/2`). Each model, and thus each set of assumed facts, must obey the constraint. The Prolog reasoner does the same consistency test on the facts that it assumes (`reasoner:consistent_assumptions/4`) |
| `for all cases in which C it is the case that G` | the negation of a helper rule that searches for a counter-example (the Lloyd–Topor transformation): `not le_forall_K(Shared)` together with `le_forall_K(Shared) :- C, not G.` The helper is necessary because the `forall/2` of s(CASP) can use only one variable at a time, and s(CASP) has no `call/1` |
| The `is_a/2` clauses of the ontology section | clauses of the unit, the same as all other clauses |
| Decision tables, service conditions, `according to` in a rule, `the minimum/maximum of`, a sentence used as a condition (`… is the case`), a condition with no template | one reported problem for each, because the system cannot translate them (§8). The system never puts a Logical English record into the output without a translation |
| Each user template | a `#pred` directive with the Logical English sentence. The directive marks the slots with `@` and gives their types (`pred_directive/2`). The directive controls the `--human` output of s(CASP). It also checks again the sentences that we write ourselves |
| Comparisons `>`, `>=`, `<`, `=<` | **CLP(ℚ) constraints** `#>`, `#>=`, `#<`, `#=<`. These constraints are permanent requirements on a number. They are not tests of a known number |
| Equality / assignment (`is`, `=`) on numbers | `#=`, also a permanent requirement. Between things that are not numbers, usual `=` |
| Arithmetic `+ - * /` etc. | not calculated: it stays inside `#=` as a requirement on the numbers, never `is/2` |
| `is in` (list membership) | `member/2`. s(CASP) runs `member/2` constructively. Thus it also operates under a negation, and in a universal statement whose element is not known yet |
| Scenario facts | clauses in the unit, with all values filled in |
| Scenario rules (`a thing belongs to a set if the thing is in the set`, in a scenario) | translated in the same way as the rules of the program, and added to the unit for that scenario only. Before September 2026, the system copied these rules without a translation. Thus their conditions named nothing that s(CASP) knew, and the rule was never true |
| A query (`which person is happy and the person is rich`, a custom query) | translated as a rule body (`le_scasp_query_goal/6`) into the clauses of a helper, `le_query(Vars)`. The arguments of the helper are the variables of the query. The system then asks s(CASP) about the helper. The explanation shows the conditions of the query, not the helper. Before the helper existed, a query of more than one condition went to s(CASP) as the `and/2` of Logical English. The unit does not define `and/2` (`existence_error: scasp_predicate …:and/2`). The helper also prevents an error for a query about a predicate with no clause in the unit (no rule and no fact in this scenario). The query then has no answer, the same as in Prolog |
| Where a document is published, where its text is (`… is published at …`, `the text of … is at …`) | not written: these are records that the citations of the explanation read. They are not clauses of the program |

### Constraints are relational, not functional

Of all the translation decisions, this decision is the most important.
`an amount is greater than 25000` becomes `Amount #> 25000`. This is a requirement
that the amount must obey. It is not a test on an amount that is known. Because the
requirement is independent, the system can answer a query **with no scenario**. The
answer then comes back *as a condition on the amount*, not as a number. This is the
most important feature (§5).

### DNF clause-splitting

s(CASP) does not let you use `;/2`, the *or*, in the body of a clause. Thus
`body_to_dnf/2` distributes each `;` over the `,` around it. In other words, it
multiplies each *or* out over the *and*s. The result is one clause for each
combination of conditions. `body_to_dnf/2` uses only `append/3` for this work, never
`findall`. The reason is that `findall` copies the terms. A copy breaks the
connection between a variable in the head and the same variable in the body. Then
the answers come back with no values filled in. The system prints each clause that
results as one unit. Thus the variables in its head and the variables in its body
still agree.

---

## 5. Answers: constraints, multiple models, abduction

A Prolog answer fills each variable of the question with a specific value. An
s(CASP) answer can give more information than that. Thus the answers pane has three
more functions.

### Constraint / symbolic answers (§5b)

Sometimes the answer still has a variable **with no value**. Then
`le_scasp_symbolic_goal/4` reads the arithmetic requirements that s(CASP) attached to
that variable. `copy_term/3` gives these requirements. Then
`le_scasp_symbolic_goal/4` changes each comparison into English (`greater than`,
`less than or equal to`, and others). It names the value with **the noun that the
template gives for the type of that slot**. For example, examine this program:

```
a claim of an amount is covered if the amount is greater than 25000.
```

Ask `a claim of which amount is covered`, with no scenario. The answer is:

> *a claim of **any amount greater than 25000** is covered*

The result has `symbolic: true` and a list of `constraints`. With such an answer, a
user can ask *"under what conditions would this hold?"*, and get a direct answer.

### Multiple models — "possible worlds" (§5a)

One query can give several stable models. Each model has its own values for the
variables, its own set of true facts, and its own justification. s(CASP) gives a
model for **each possible combination of true and false values of the assumable
facts that the proof did not need**. Thus the same "possible world" can come back
many times. For this reason, the server does three things:

1. It makes one result for each model (`scasp_answers_json/3`).
2. It **deletes the duplicates**. Two results are the same when they have the same
   answer sentence and the same set of assumptions, in any sequence
   (`scasp_dedup_results/2`).
3. It gives numbers to the remaining results, from one upwards, as `modelIndex` of
   `modelCount` (`number_results/4`).

The editor gives each remaining card the label **"world *i* of *n*"**
(`explanation-view.ts`). On the `/executive` page, the same label is "possible
worlds". Usually there is only one model in legal reasoning. When there is exactly
one model, the editor hides the label, and the screen is the same as before.

### Abduction — assumption sets (§5c)

To make the query true, a model possibly had to **assume** some of the assumable
facts. `le_scasp_assumptions/3` goes through the justification tree. It collects each
fully known `abduced` or `assume` atom. It does not use the part of the tree that
s(CASP) keeps for its own internal checks. Then `le_scasp_assumptions/3` deletes the
duplicates and writes the assumptions in Logical English. The assumptions go to the
editor by the **same `unknowns` route** that the Prolog engine uses for the facts
that it assumes. Thus the amber "?" marker and its tooltip show the assumptions, with
no change to the editor. Assumptions answer the question *"what would have to be
true for X to hold?"*. An example is
`examples/moreExamples/language/abduction/loan_approval.le`. That example has four
different worlds, and each world has its own set of assumptions.

---

## 6. Explanations

s(CASP) gives its justification as a tree in the form `Node-Children`. Each `Node` is
`goal_origin(Atom,Ref)`. Sometimes one of `assume/abduced/chs/proved/not/-` contains
the node. `le_scasp_tree_json/4` changes that tree into the **same shape of
explanation tree** that the screens already read. The tree is in JSON (JavaScript
Object Notation, a plain-text format for data):
`{type, literal, children[, start, end, naf, assumed, classicalNegation]}`. That shape
tells how to show an explanation, not how the system proved it. Thus all of the
current explanation display operates with no change:

- the colours and the tooltips,
- the opening and closing of a step,
- the numbers of steps in steps,
- the folding of a sub-explanation that occurs again,
- the Explanation Drill and Copy as Mermaid,
- a click on a step to go to the sentence that it came from.

`node_atom_status/4` and `apply_flags/3` change the state of a node into what the
display shows:

| s(CASP) node | JSON `type` | flag |
|---|---|---|
| plain atom, `proved` | `success` | — |
| `not A` (constructive negation) | `failure` | `naf: true` |
| `-A` (classical negation) | `failure` | `classicalNegation: true` |
| `assume(A)` / `abduced(A)` | `unknown` | `assumed: true` (amber) |
| internal `o_nmr_check` / `o_chk_*` | *deleted* | — |

**The system proves a negative statement. The statement is not only missing.** In
Prolog, when `\+ G` is true, the only fact is that the system could not find `G`.
The explanation shows a red "could not be proven" leaf. In s(CASP), the system
*proves* `not G`, with rules that s(CASP) makes for the negative case. Thus the tree
has a real proof of why `G` fails, one rule at a time (the `naf` nodes). Such a proof
explains a failure much better. The Prolog preference "Detailed failure explanations
(per-rule nodes)" tries to give approximately the same result.

**Trace is only for Prolog.** When s(CASP) is the engine, the editor disables the
step-by-step Trace button (`editor/src/client.ts`). The reason is that the
justification tree replaces a trace.

---

## 7. Negation: De Morgan normalisation

In the body of an s(CASP) rule, a negation must have the form **`not <literal>`
only**. `not` can be in front of one single condition and nothing more. s(CASP) does
not accept `not (a ; b)`, `not (a , b)` or `not not a`. But Logical English lets you
use `and` and `or` freely in `it is not the case that …`. Thus `demorgan_negate/2`
moves the negation inwards until the negation is in front of single conditions.
`lower_body(not(G))` calls `demorgan_negate/2`:

- `not (A or B)` → `not A and not B`
- `not (A and B)` → `not A or not B` (then DNF removes the `;`, §4)

This change does not change the meaning, if the negation is negation as failure.
**A negation of a negation**, however, is not possible in this version of s(CASP).
The translation gives the error
`le_scasp_untranslatable(scasp_double_negation)`. `emit_rules/4` catches the error.
Thus the system tells the user exactly what the problem is, and the program does not
stop with an error. The problem blocks the program. Thus the s(CASP) engine does not
accept the program (§8), and the program runs with Prolog only.

`run_models_recover/3` gives more safety. Possibly s(CASP) still gives a
`permission_error` or a `determinism_error` during the run. Then
`run_models_recover/3` changes the error into an `unsupported_construct` problem.
Thus the user reads what went wrong. The web server does not report only an internal
failure (an HTTP 500).

---

## 8. Unsupported constructs → issues (errors)

Sometimes a Logical English construct has no equivalent in s(CASP). In this case,
the translation does **not** fail silently. The translation reports
`le_scasp_issue(Kind, RuleID, Message)`. `RuleID` names the rule that contains the
construct. The system **does not accept** a program with such a construct:

- "See s(CASP)" shows no program. It shows only the list of problems, with the line
  of each problem.
- The s(CASP) engine does not run the program. (`scaspQuery` answers with an error
  that has the same list.)

The system does not accept the program intentionally. The translation keeps a text
for its own use. In that text, `le_scasp_program_text/3` puts `true` in place of the
condition that it could not translate. This makes the rule apply in more cases. Thus
the text would have a meaning that is different from the Logical English.

`le_scasp_check/3` makes the list of problems. `le_scasp_blocking_issue/1` tells
which problems stop a program. All problems stop a program, but not the three
problems of the engine itself: the pack is not installed, the time ends, and the
engine does not accept a construct during the run. The converters to other systems
do not accept programs in the same way (`docs/dev/migration.md`, "Exporting: the
check before the text"). **All messages come from the translation dictionaries**
(`i18n/messages.csv`, the keys `scasp_*`). The code contains no message. Thus each
message goes to the reader in the language in use. The code that answers a request
calls `ensure_kb_language/1` first. Thus the language of the message agrees with the
language of the program.

| LE construct | Issue key | Handling |
|---|---|---|
| Totals, counts and similar (`sum/count/… of each`) | `scasp_aggregate` | not accepted — use the Prolog engine |
| `prolog <goal>` / `.pl` resources | `scasp_prolog_goal` | not accepted (Prolog only) |
| `for all cases …` (universal) | `scasp_universal` | not accepted (the system translates the usual universal statement with the Lloyd-Topor transformation) |
| Date arithmetic (`… days after …`) | `scasp_date_arithmetic` | not accepted |
| `is known` | `scasp_unsupported_known` | not accepted |
| double negation | `scasp_double_negation` | not accepted: s(CASP) cannot state it (§7) |
| `the minimum/maximum of` | `scasp_min_max` | not accepted |
| Decision tables | `scasp_decision_table` | not accepted |
| Service conditions (semantic comparisons, §17.6 of the language reference) | `scasp_service` | not accepted |
| `according to` in a rule (source-scoped proof) | `scasp_scoped_proof` | not accepted |
| a sentence used as a condition (`… is the case`) | `scasp_meta_call` | not accepted |
| a condition with no template | `scasp_missing_template` | not accepted |
| all other rules that the system cannot translate | `scasp_untranslatable_rule` | not accepted |
| query timeout | `scasp_timeout` | the system gives the answers that it found |
| a construct that the translation did not change (the `and/2` of Logical English, `le_flip/2`, a built-in condition in a comparison, a sentence with no template written as a fact, …) in a rule, a fact or a query | `scasp_leftover_construct` | not accepted: `leftover_in_clauses/2` examines each translated clause. Thus nothing that belongs to Logical English stays for s(CASP) to call. If one such construct is not found, the run reports the same problem, not an error |
| an illegal construct that stays | `scasp_unsupported_construct` | for example, an "or" that the translation could not change into separate clauses |
| pack absent | `scasp_engine_not_installed` | you cannot use the engine |

The system changes an `is different from` between two things that are not numbers
into the `X \= Y` of s(CASP). `X \= Y` states directly that the two things are
different.

> **Warning about s(CASP) 1.1.4:** The system can assume some facts. In that case, a
> global constraint can give an incorrect answer if it uses `\=` and still has a
> variable with no value. The reason is that a model can assume the thing that the
> constraint prohibits. A constraint with all values filled in gives correct answers.

All of these messages give the same advice: *"run this query with the Prolog
engine"*. The two engines complete each other. They do not compete.

---

## 9. Stratification check (verifier)

A program **makes a loop through negation** when a conclusion depends on the
negation of itself, through a chain of rules. Such a program is non-stratified. The
two engines give different results for non-stratified programs: Prolog can run
without end or give an incorrect answer, but s(CASP) calculates the stable model.

`le_scasp_stratification/2` makes a map that shows which conclusion depends on which
conclusion. It marks each dependency as positive (`pos`) or negative (`neg`). Then it
searches for a loop that goes through a minimum of one negative step, that is, a
minimum of one `not`. `verify/2` calls `le_scasp_stratification/2`. The editor then
shows a warning with the `non_stratified_desc` message, in the language of the
reader: *"…{name} depend on one another through negation. The Prolog engine may loop
or give unsound answers — consider running this query with the s(CASP) engine."*

---

## 10. Testing

- **Prolog unit tests:** `testing/test_scasp.pl` tests the translation, the use of De
  Morgan's laws (`or_positive_dnf_expands`, `or_under_negation_demorgan`,
  `double_negation_reports_issue`) and the translated messages
  (`issue_message_localized`). The same file has a **comparison test**. This test
  runs the citizenship program with the two engines. It makes sure that the two
  engines agree with the answers that the program records in its `expects answers`.
- **End-to-end tests of the editor:** `editor/tests/scasp-engine.spec.ts` tests these
  items:
  - the engine menu,
  - the selection of the engine in advance from the declaration of the program,
  - an answer that is a condition instead of a value,
  - the "world *i* of *n*" cards when there are several models,
  - the disabled Trace button with s(CASP).
- **The same run with the two engines** is the main quality check (plan §7). The
  system answers the same program, the same scenario and the same query two times.
  A difference between the two answers is a fault in the translation or a real
  difference in meaning. A real difference in meaning comes from a non-stratified
  program. The real differences are exactly those that the stratification warning
  shows.

Demo files:

| File | Feature |
|---|---|
| `examples/moreExamples/language/scasp/dual_engine_demo.le` | loop through negation — Prolog gives no answer, s(CASP) finds the stable model |
| `examples/moreExamples/language/scasp/clp_coverage.le` | §5b, an answer that is a condition instead of a value |
| `examples/moreExamples/language/abduction/sunglasses.le` | §5c, a set of assumptions |
| `examples/moreExamples/language/abduction/loan_approval.le` | several models — 4 possible worlds, each world with its own assumptions |

---

## 11. Guidance: which engine, when

- **Prolog** (the default): programs with no loop through negation, totals and
  counts, `prolog` goals, large collections of facts, and arithmetic on dates. Prolog
  is much faster.
- **s(CASP)**: programs with a loop through negation, exact arithmetic and answers
  that are conditions, the question "what must be assumed?" (abduction), and rules
  whose variables have too many possible values to list. Also use s(CASP) when the
  *quality of the explanation of a failure* is the most important thing.

The stratification check gives the same advice as a hint in the editor. The user
makes the decision.

---

## 12. Current status and known limitations

Work packages 1 to 7 of the plan are complete, with the tests of §10. The remaining
work is small improvements. None of these items stops you from working:

- **There is no "Both" view yet.** Such a view would show the answers of the two
  engines next to each other. The comparison exists only as the test that runs the
  two engines.
- **A number in a condition has no formatting.** It has no thousands separator and no
  grouping for the country of the reader (`25000`, not `25,000`).
- **A step points to a full conclusion, not to one condition**
  (`kb_pred_source/4`). When you click a step of the tree, the editor highlights the
  head of the rule that defines it, or the template. It does not highlight the exact
  condition. The `assert_scasp_source_reference/3` of s(CASP) could make this more
  precise.

### Forward compatibility (browser)

The two engines are SWI-Prolog libraries. The SWI-Prolog version of s(CASP) is
written only in Prolog. Thus all of the design can move with no change to
`swipl-wasm`. `swipl-wasm` runs SWI-Prolog in a web browser. In the browser, the
engine menu would select which of the two libraries answers, on the computer of the
reader. The part that reads Logical English would run in the same copy of Prolog.
`le_scasp_query/6` runs a query. It needs nothing that only a server can give, but
it loads the temporary file. In the browser, `le_scasp_query/6` would load the
program from memory.

---

## 13. Code map

| Concern | Location |
|---|---|
| Write the s(CASP) program: `#pred`, `#abducible`, opposites, De Morgan's laws, the CLP constraints, multiply out the `or`s | `le_scasp.pl` — `le_scasp_program_text/3`, `lower_body/5`, `lower_leaf/3`, `demorgan_negate/2`, `body_to_dnf/2` |
| Run a query (Mode A, the time limit, collect the models) | `le_scasp.pl` — `le_scasp_query/6`, `load_scasp_unit/4`, `run_models/6` |
| Change the justification into the form of the display | `le_scasp.pl` — `le_scasp_tree_json/4`, `node_json/3`, `node_atom_status/4` |
| Answers that are a condition instead of a value | `le_scasp.pl` — `le_scasp_symbolic_goal/4` |
| The sets of assumed facts | `le_scasp.pl` — `le_scasp_assumptions/3` |
| Search for loops through negation | `le_scasp.pl` — `le_scasp_stratification/2`; called from `le_verifier.pl` |
| The web requests `getScasp` and `scaspQuery`, and the deletion and numbers of duplicate models | `classic_web_api.pl` — `handle_get_scasp/2`, `handle_scasp_query/2`, `scasp_dedup_results/2` |
| The sentence that declares the target language | `le_grammar.pl`, `le_kbs.pl` — `kb_target_language/2` |
| The engine menu, "See s(CASP)", the disabled Trace button, the world label | `editor/src/client.ts`, `editor/src/explanation-view.ts`, `editor/src/i18n.ts` |
| The words of the problems, in all languages | `i18n/messages.csv` — `scasp_*`, `non_stratified_desc` |
| Tests | `testing/test_scasp.pl`, `editor/tests/scasp-engine.spec.ts` |

## 14. Reading s(CASP) back (September 2026)

`le_writer:prolog_file_to_ir/3` reads an s(CASP) program back into Logical English.
This is the same translation in the reverse direction
(lpsPlus/docs/migration/roadmap.md §5.7, Phase 2c). Each part of the s(CASP) program
gives information:

- `#pred` gives the templates again, and `@(X:type)` names each slot in a template.
- `-p` gives the opposite form again.
- `#abducible` gives the `; unknown` addition again.
- A `le_forall_K` helper gives the universal statement again.
- `#>`, `#=` and the other symbols give the comparisons and the assignments again.
- A denial gives a query for which the scenarios expect no answer (convention N1).
- `?-` gives a query again.

`testing/scasp_roundtrip.pl` is the check for the two directions. The check takes the
core collection of programs. It changes each program from Logical English to s(CASP),
back to Logical English, and to s(CASP) again. On 16 September 2026, this target
could write 88 programs. For 84 of these programs, the result was the same s(CASP)
program: the same clauses, the same assumable facts, the same constraints on opposite
forms and the same `#pred` words. Only the names of the variables were different.

Four programs came back different:

- One program has two templates that use the same predicate but give different types
  to its slots.
- One program has a universal statement that has no content.
- One program has an unknown that is only partly filled in.
- One program is the ontology-rule case that `le_writer_roundtrip.pl` also does not
  include.

(One more program was broken intentionally: a sentence with no template was written
as a fact. The system now does not accept that program, §8.)

The work on the check found four faults in this target. All of these faults are now
repaired:

- The system wrote universal statements as the `forall/2` of Prolog. s(CASP) does not
  accept `forall/2`.
- The system wrote opposite forms as separate predicates, with constraints that had
  no effect, not as `-p`.
- The system made elements of a scenario assumable.
- The system wrote the records of Logical English (the ontology record, the flip
  expectations, the services) into the program as facts. Until 16 September 2026, it
  also wrote the addresses of a document (`le_text_at/2`, `le_published_at/2`) as
  facts.

The constraints on the opposite forms now name their variables:
`false :- p(A), -p(A).`, not `_126456`.
