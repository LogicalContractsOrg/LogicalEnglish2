# Drools DRL → Logical English (Phase 2e)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The translator of the design notes `roadmap.md` §5.3 (DRL). LPS2
already reads DRL (`lps_drools.pl`, its M12d): a rule is a reactive
rule, `insert` / `modify` / `delete` are actions with their causal laws. This
translator writes that reading as **Logical English**, in two readings of the
same parse, and checks both against **Drools itself**.

**That reader is LPS2's**: `src/syntax/lps_drools.pl` in the LPS2
repository, its front end for DRL. This translator loads it from the LPS2 it
finds (`../le2_paths.pl`: a checkout beside LE2, or `$LPS2_DIR`), so the
Drools door needs LPS2 as well as LE2.

| File | What it does |
|---|---|
| `drl_twin.pl` | the twins: the stateful reading (LE for LPS) of every rule base and the stateless reading (timeless LE) of a rule base that only inserts; the oracle's cases; the final-state comparison |
| `oracle/` | the Drools oracle: `DrlOracle.java` (Drools 10.2, a KieSession with an agenda listener) runs a rule base on a working memory and the steps a Java driver takes, and reports every rule that fired with what it inserted, updated and deleted, and the final working memory; `describe` reads a fact model's fields. `mvn -q package`, then `drl-oracle.sh spec.json` |
| `corpus/` | the rule bases (`drl/`) and the Java fact model of the Drools examples (`java/`, Apache License 2.0); `compile_model.sh` compiles it into `model/` |
| `corpus.pl`, `build.pl` | the cases (DRL, model, initial working memory, driver steps) and the build into `lps2/examples/migration/drools/` |
| `drl_import.pl` | File ▸ Open of a `.drl` (LE2's `le_import.pl` registry) |
| `test_drools.pl` | plunit: each stateful twin ends where Drools ends; each decision twin passes; the adapter |
| LPS2's `src/syntax/lps_drools.pl` | **LPS2's DRL front end** (its M12d): DRL to LPS internal syntax, and the world reading everything above is written from |
| LPS2's `tools/drools_test.pl`, `tools/drools_fixtures/` | that reader's own gate: eighteen rule bases against their expected firing sequences and eleven readings of one construct each |

## How to run

```sh
(cd migration/drools/oracle && mvn -q package) && migration/drools/compile_model.sh
./myswipl.sh -q migration/drools/build.pl
./myswipl.sh -q -g run_tests -t halt migration/drools/test_drools.pl
```

The reader's own gate, from this repository's root (it needs an LPS2 checkout
beside it, or `$LPS2_DIR`; it points LPS2's `LPS_PLUS_DIR` back at itself, so
it tests these files):

```sh
(cd ../lps2 && ./myswipl.sh -q -g "consult('tools/drools_test.pl')" -g "drools_test:main" -t halt)
```

## The two readings

**Stateful** (LE for LPS, every rule base), in LPS2's **world reading**
(`lps_drools.pl`): in LPS an action or an event is something that happens in
the world, not an operation on a store, so the twin is about the world the
working memory describes, not about the memory.

- Each fact type is a fluent worded as a state of the world: `there is a fire
  in *a room*`, `there is a policy for *a driver* with band *a band*`. A
  **boolean field is a state of its own**: `the sprinkler in *a room* is on`
  (`on == false` is its negation). A field that every fact of the rule base
  (the DRL, the initial working memory, the driver's steps) gives one same
  value tells no two facts apart and is **left out** — `new Alarm( "house1" )`
  is just *an alarm* — with a ledger entry saying so. Drools' facts are
  objects, not individuals with names: the twin invents none.
- What a rule does to working memory is an **event in the world** with its
  causal law: an insert is the thing starting (`a fire starts in *a room*`),
  a delete its ending (`the fire in *a room* ends`), a modify of a boolean
  the object turning on or off (`the sprinkler in *a room* turns on`; for
  other booleans `becomes honest` / `stops being honest`), a modify of
  another field that field becoming its new value (`the band of the policy
  for *a driver* becomes *a band*`).
- Each rule is a reactive rule **with no times**: its conditions read one
  state and its events start from it, together, as a DRL consequence is one
  block (`if there is a fire in a room and it is not the case that an alarm
  is on then an alarm goes on.`, LE2's `le_lps_surface.md` §3.1).
- **Refraction**: Drools fires a rule once per match, LPS in every cycle its
  conditions hold. A rule whose one change is an insert is guarded by the
  inserted fact not holding yet — `and it is not the case that an alarm is
  on` — unless the DRL already has such a `not`; a rule that modifies or
  deletes what it matched guards itself.
- **Words**: a translator cannot know that an alarm "goes on". The defaults
  state plainly what holds and what happens; a **wording table** beside the
  DRL, `<stem>.wording` (copied into the twin's `sources/`), gives the words
  and names a person would choose. One line per fluent or event, keyed by the
  name the reading gives it (the twin's declarations list them), with a place
  `*a …*` for each of its values and optionally its LPS name:

      % Fire.wording
      alarm: an alarm is on
      alarm_starts: an alarm goes on; known as alarm_goes_on
      alarm_ends: the alarm goes off; known as alarm_goes_off
      fire_ends: the fire in *a room* is put out; known as fire_is_put_out

  A line with the wrong number of places, or for something the rule base
  does not have, is reported (a warning of the reading) and ignored.

`insertLogical` (truth maintenance) is an **intensional fluent** (`there is a
hope at a time if the politician called a name is honest at the time`), which
is what it means: the fact holds while its support does (LPS2's reader reads it
so itself; where a rule also inserts, modifies or deletes that type, or the
working memory holds it from the start, it is an insert, with a warning). A
rule whose whole consequence is Java (`System.out.println`) is a residue block
with the Java, and Java beside a working-memory change a comment on the rule
(LPS2's own reading performs `java_leaf(Rule)` in its place, which the twin
leaves out); salience a comment and an *approximated* ledger entry (LPS has no
conflict-resolution priority), counted once. `or` between patterns is one
reactive rule per alternative. An `accumulate` is an aggregate sentence (`a
total is the sum of each a value such that …`), which compiles back to LPS2's
own reading (`findall` and `sum_list`). Rule attributes as LPS2's reader
reads them (`lps2/docs/user/integrations/drools.md`): `no-loop` is the
condition that the rule's change is not made already, a rule with `enabled
false` is a comment saying it is left out (an *encoded* entry), and each
attribute not translated (`agenda-group`, `activation-group`, a timer, a
calendar window, `lock-on-active` beyond `no-loop`) is named in the rule's
comment and makes its entry *approximated*, with the reader's warning. A
value computed in Java is computed where the reader can (`$p.getName()`,
`$total.intValue()`, `$c.getCount() + 1`, the last as the old fact ending and
the new one starting), and otherwise its change is Java (a comment, or a
residue block when nothing else is left). A rule LPS2's reader does not
translate (`eval`, `forall`, `collect`, `average`, …), and one whose reading
Logical English for LPS cannot write yet (a `not` over a pattern with a
comparison), is a residue block with its DRL and the reason. File ▸ Open's
note counts the ledger's rule entries: encoded, approximated (salience, a rule
attribute, a value computed in Java), residue. The initial working memory is `initially`; the facts a Java driver
inserts and deletes between two `fireAllRules` are a scenario of observed
**events** (a fire starting, a fire being put out: the world's, declared under
`the events are`, not the rules' actions), ten cycles apart.

**Stateless** (a rule base with no `modify` or `delete`: a decision
service): timeless LE. Each inserted type is concluded by rules, **one LE
rule per DRL rule, in salience order**, each with its name and salience in
the comment above it — the reading closest to the rule base, and a
deterministic one. Drools fires only the first (by salience) of the rules
matching one case; a rule whose conditions do not already exclude those of a
rule of higher salience (one being the negation of the other's, as in
`discount.drl`) says so with `it is not the case that` and that rule's own
conditions. The
*refraction guard* (`not Discount( customer == $customer )` in the rule that
inserts a Discount — Drools' way of firing once) is left out, since a
timeless rule concludes once by itself. The Drools run's inserted facts are
the scenario's expected answers.

The fact model: a rule base's `declare`s, or, for one written against Java
classes, the classes' fields in declaration order and types (`DrlOracle
describe`), a field that holds another object being that object's name
(`Sprinkler(room, on)` is `sprinkler(kitchen, false)`, which the world reading
reads as `there is a sprinkler in kitchen`). The oracle's final working memory
is read the same way before it is compared with the twin's final state.

## Results (14 September 2026; rebuilt in the world reading 15 September)

| Case | Source | Rules | Stateful twin vs Drools (final working memory) | Decision twin |
|---|---|---|---|---|
| `fire_alarm` | Drools examples, `fire/simple/Fire.drl`, with FireExample's driver (four rooms, fires in two, then out) | 7 (3 Java only) | the same | — |
| `honest_politician` | Drools examples, `HonestPolitician.drl` (insertLogical) | 4 (2 Java only) | the same (Hope gone once the last politician is corrupted) | — |
| `insurance` | LPS2's rule base, as valid DRL | 3 | the same | — |
| `discount` | LPS2's rule base, as valid DRL (salience) | 2 | the same | 1/1 (best for the gold customer, standard otherwise) |
| `shipping` | LPS2's rule base, as valid DRL (delete) | 2 | the same | — |

Five of five stateful twins end, under LPS2, in the working memory Drools
ends in; the decision twin reproduces the facts Drools inserted. What does
not carry over is said where it happens: the Java of the consequences, the
salience (a firing *order* LPS does not have — the final states agree
because these rule bases do not depend on it), and the per-activation
refraction of Drools, which the twins approximate by a condition (a rule that
only inserts waits until what it inserted is gone: the fire alarm goes on once,
at cycle 12, and off once, at cycle 22); a println would still print again
wherever a rule's conditions keep holding. Left out as telling no facts apart:
the alarm's name (fire_alarm), the one stock's item (shipping).

## What building this changed in LPS2 (`src/syntax/lps_drools.pl`)

Real DRL, not only the restated examples: a rule name without quotes and
`when` on the rule's line; `not( … )` and `exists( … )` with parentheses;
`$` bindings; comparisons other than `==` (`!=`, `<`, `>`, `<=`, `>=`) as
conditions; `s.room` (a field of another pattern's fact); setters in `modify`
blocks (`modify( s ) { setOn( true ) }`) and blocks over several lines;
`drl_to_internal/4` with the field order of undeclared types (the fact
model). A `modify` now changes the very fact the rule matched (it used to
build a fresh copy of the pattern, so the action carried an unbound key —
`tools/drools_test.pl`'s traffic-light and shipping expectations are
corrected accordingly, 8/8). 15 September: the *world reading* (above) —
`drl_reading/3` with the working memory's facts and the wording table,
`drl_world_facts/3`, `drl_driver_events/4`, `drl_event_laws/3`,
`drl_templates/2`; the consequence's events start at the conditions' time.
LPS2's own `examples/drools/fire-alarm.drl` now reads `if fire(A) at T1, not
alarm at T1 then alarm_goes_on from T1 to T2` (with `fire-alarm.wording`).

16 September (bugs found by running both doors on real DRL files): a field a
condition compares with a constant is no longer left out when the working
memory is unknown (`not Customer( tier == "gold" )` had become "no customer");
`or` (and `||`), `accumulate` (`sum`, `count`, `min`, `max`), a comparison
under `not`, and `insertLogical` (an intensional fluent) are read; conditions
that are not (`eval`, `forall`, `collect`, …) leave their rule out with a
warning; a type with no `declare` takes fields from `s.room` and from getters
in the Java, with a warning; Java beside a change performs `java_leaf(Rule)`;
a rule name containing "when" no longer loses its conditions; an insert with
arguments gets its refraction guard. `tools/drools_test.pl`: 16/16 and 7
readings, the constructs in `tools/drools_fixtures/`, their expectations
checked against Drools with this oracle (a valid-DRL version of the `or`,
`accumulate`, `insertLogical` and `not`-with-a-comparison rules). The twins'
programs did not change; their ledgers no longer count each salience twice.
Later that day: rule attributes (`no-loop`, `enabled false` translated, the
others a warning each) and values computed in Java (accessors, `xValue()`,
arithmetic; any other Java leaves its change out, where it used to become a
constant), checked against Drools 10 (`tools/drools_fixtures/attributes.drl`,
`values.drl`; `drools_test.pl` 18/18 and 11 readings); an `accumulate` is
written as an aggregate sentence instead of a residue block, now that Logical
English ends an aggregate where the conditions after it begin. The five
twins did not change (no attribute, no computed value, no accumulate).
