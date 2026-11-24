# Ponens policies ↔ Logical English for LPS

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

*Kind: developer guide · Audience: developers · Status: current (October 2026)*

Ponens (`github.com/imandra-ai/ponens`, MIT licence) checks the trace of a
software agent's session against **policies**: formulas of temporal logic
that say what must hold at each step. This translator reads a pack of Ponens
policies as one document in Logical English for LPS (LE for LPS), which LPS2
runs. Each Ponens trace becomes a scenario of that document. The translator
also writes a program in the same vocabulary back as Ponens policies.

| File | What it does |
|---|---|
| `ponens_import.pl` | The entry for File ▸ Open (a `.json` pack of policies) and for File ▸ Export |
| `ponens_twin.pl` | A pack of policies as LE for LPS: each policy is a law that records a breach, each trace a scenario |
| `ponens_formula.pl` | The parser and printer of Ponens's formulas |
| `ponens_reading.py` | Asks Ponens's own code which atom holds at which action of a trace |
| `ponens_writer.pl` | The way back: each law that records a breach, written as a Ponens policy |
| `ponens_build.pl`, `ponens_publish.py` | Build the twins of Ponens's gallery and copy them into LPS2's `examples/migration/ponens/` |
| `ponens_run.pl`, `ponens_gate.py` | The gate: the twins run by LPS2, compared with the verdicts of Ponens's own evaluator |
| `test_ponens.pl` | The tests of the reader and of the way back |

```sh
swipl -q -g run_tests -t halt migration/ponens/test_ponens.pl
python3 migration/ponens/ponens_gate.py --ponens <a checkout of Ponens>
```

The tests need LE2 (this repository). The gate needs LPS2 too, beside LE2 or
named by `$LPS2_DIR`, and a checkout of Ponens.
