# Checking the DfE funding program against a second reading

*Kind: how-to · Audience: developers · Status: written 13 October 2026*

There is no Oracle engine to check `dfe_16_19_funding.le` against, so it is
checked against a second, independent reading of the same pages: a Python
program written by another agent that never saw the Logical English.

| File | What it is |
|---|---|
| `schema.md` | the test-case format: one JSON file per student, with the field names of the interface agreement (pages 20-36) |
| `ref/dfe_ref.py`, `ref/run_ref.py` | the second reading: `calculate(case)` gives the 38 outputs of pages 34-36 |
| `ref/NOTES.md` | how the second reading treats Oracle's unknown and uncertain values, and its 26 reading choices |
| `ref/cases/`, `ref/make_cases.py` | its 96 test cases, designed to cover every rule |
| `random_cases/make_random_cases.py` | 300 random students (fixed seed), written into that folder |
| `json2le.py` | JSON cases → Logical English scenarios that include the program |
| `output_queries.txt` | one query per output, named after its Public Name |
| `run_le.pl` | asks every query in every scenario; one JSON line per case |
| `compare.py` | compares the two, output by output |
| `expectations.pl`, `build_examples.py` | write the scenarios and expected answers of the program and of `../dfe_16_19_funding_tests.le` |

## Repeat the comparison

From `examples/regulatory/dfe_funding/`:

```sh
python3 check/ref/run_ref.py --no-intermediate check/ref/cases/*.json > /tmp/ref.jsonl
python3 check/json2le.py dfe_cases_tmp.le check/ref/cases/*.json
(cd ../../.. && ./myswipl.sh -g "use_module(le_kbs)" \
    examples/regulatory/dfe_funding/check/run_le.pl \
    examples/regulatory/dfe_funding/dfe_cases_tmp.le) > /tmp/le.jsonl
python3 check/compare.py /tmp/ref.jsonl /tmp/le.jsonl
rm dfe_cases_tmp.le
```

The case file must sit beside the program, because a program may include only
resources in its own folder. The Logical English run takes about two minutes
for the 96 cases.

For the random students, run `python3 check/random_cases/make_random_cases.py`
first and use `check/random_cases/*.json` (about nine minutes).

Results on 13 October 2026: 3,622 of 3,648 outputs equal on the designed
cases, 11,397 of 11,400 on the random ones; every difference is a case where a
value the rules need is missing (the program's README explains why).

## Rebuild the expected answers

After a change to the program:

```sh
python3 check/ref/run_ref.py --no-intermediate check/ref/cases/*.json > check/ref/ref_out.jsonl
python3 check/build_examples.py check/ref/cases check/ref/ref_out.jsonl
rm check/ref/ref_out.jsonl
```

It keeps only the cases on which the two readings agree everywhere, and writes
the expected answers from the program's answers (about four minutes).
