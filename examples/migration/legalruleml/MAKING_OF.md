# How the examples in this folder were made

Every program here is a *twin*: an example of the LegalRuleML standard
rewritten in Logical English by a translator, a Prolog program that reads the
XML and writes the twin. The originals are the examples of the OASIS
LegalRuleML Core Specification, written by its authors. LegalRuleML ships no
tests, so the scenarios, and the English wording of relations whose names are
not English, were drafted by an AI agent (Claude, in Claude Code); the answers
those scenarios expect were computed by SPINdle, the defeasible logic reasoner
of Ho-Pun Lam and Guido Governatori, which the specification acknowledges as
the engine used for testing LegalRuleML. SPINdle does not read LegalRuleML:
a second program of the translator (`lrml_spindle.pl`) writes each example,
with a scenario's facts, as a theory in SPINdle's own format, and SPINdle runs
on that theory. The translator itself was also written by the AI agent, at
Miguel Calejo's request.

| File | Made by | How |
|---|---|---|
| `*/<example>.le` | Translator program `migration/legalruleml/build.pl` of this repository (`main/1`, which calls `lrml_twin:build_twin/3`) | Reads the XML with `lrml_reader.pl` and writes the program through LE2's `le_writer.pl` and `le_migration.pl`. Scenarios and wording come from `migration/legalruleml/corpus.pl` (see below); expected answers from SPINdle 2.2.4 (copyright NICTA, GNU Lesser General Public License; downloaded for the build, not kept in this repository), run by `lrml_spindle.pl`. The opening disclaimer comes from `le_migration:with_disclaimer/2`. |
| `*/<example>.ledger.md`, `*/<example>.ledger.json` | The same translator (`le_migration.pl`) | What each statement of the original became: encoded, approximated, or left for a person. The ledger marks the reviewer's wording as the reviewer's, not the translator's. |
| Scenarios and wording, inside each `.le` | AI agent (Claude, in Claude Code), 14–15 September 2026 | Written in `corpus.pl` from each example's paraphrases and from the law it encodes, as "the reviewer's wording" and "drafted scenarios". The ledger notes explaining remaining warnings (`ledger_notes`) were written there too. Only their expected answers are computed, by SPINdle. |
| `*/deontic.le` | A copy of LE2's `lib/deontic.le`, put there by the translator | The library of obligations, permissions and prohibitions. It was written by the AI agent (commit `b97d42f`, 14 September 2026). |
| `*/sources/*.lrml` | People: the authors of the LegalRuleML Core Specification (OASIS LegalRuleML Technical Committee) | The specification's examples, unmodified, from https://docs.oasis-open.org/legalruleml/legalruleml-core-spec/v1.0/os/examples/ (LegalRuleML Core Specification Version 1.0, OASIS Standard, 30 August 2021; copyright OASIS Open 2021, whose notice is kept in full in `NOTICE.txt` in this folder and in `migration/legalruleml/corpus/oasis/NOTICE.txt`). |
| `README.md` | AI agent (Claude, in Claude Code), at Miguel Calejo's request (it came from InsurLE2 with the twins on 16 September 2026 and was rewritten on 23 September) | Written by the agent itself, not by the translator. |
| `MAKING_OF.md` | AI agent (Claude, in Claude Code), 24 September 2026, at Miguel Calejo's request | This file. |

## The record

- Commit `67595ba` (14 September 2026) "Phase 2f: LegalRuleML both ways,
  checked by SPINdle", in the InsurLE2 repository, by Miguel Calejo with
  Claude Opus 5 (the commit's `Co-Authored-By` line): the reader, the
  translator, `corpus.pl` and the first build. Commits `0c8f948` and
  `1a78692` (15 September) followed a review of the twins, again by
  translator changes and a rebuild.
- The translator moved to the lpsPlus repository on 18 September 2026 (commit
  `44d3f65` there), and from there into this repository, as
  `migration/legalruleml/`, in November 2026, when the translators became
  open source; the twins moved into this repository on 16 September
  (commit `9d42150`, "move examples"). Later changes here came from rebuilds
  after translator or writer fixes; the record shows no hand edit of a twin.
- To build the twins again, from the LE2 checkout, with Java for SPINdle:

  ```sh
  migration/legalruleml/oracle/fetch_spindle.sh
  ./myswipl.sh -q migration/legalruleml/build.pl
  ```

  The ledgers of the twins are from the builds of 15 and 23 September 2026.
  On 24 November 2026 the line of each ledger that names the translator was
  corrected in place, from the earlier private place to
  `migration/legalruleml`.
