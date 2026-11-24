# How the examples in this folder were made

Every program here is a *twin*: a program of s(CASP), a reasoner for logic
programs, rewritten in Logical English by a translator, a Prolog program that
reads the s(CASP) file and writes the twin. The originals come from the test
folders of the s(CASP) package. Thirteen of them are themselves translations:
the first Logical English (LE1) turned documents written by its authors into
s(CASP). The other four are classic programs by the authors of s(CASP) and of
s(ASP), the system that s(CASP) is based on. No person
and no AI agent wrote the twins by hand; the translator, and this folder's
README, were written by an AI agent (Claude, in Claude Code) at Miguel
Calejo's request.

| File | Made by | How |
|---|---|---|
| `*/<name>.le` | Translator program `migration/scasp/build.pl` of this repository (`main/1`, which calls `scasp_twin:build_twin/3`) | Reads the source with `scasp_source.pl` and LE2's own reader `le_writer:prolog_file_to_ir/3`, then writes the program through `le_writer.pl` and `le_migration.pl`. The scenarios are LE1's scenarios and the source's `?-` queries. The expected answers are s(CASP)'s own, run on the original. The opening disclaimer comes from `le_migration:with_disclaimer/2`. |
| `*/<name>.ledger.md`, `*/<name>.ledger.json` | The same translator (`le_migration.pl`) | What each clause became. Notes on remaining warnings come from `source_diagnostics/6`; one note on `obligation` (its nested "that" sentences) was worded by the AI agent, as a `hand_note/3` in the translator. |
| `*/sources/*.pl` | People: for 13 programs, the LE1 authors (written in LE1, then translated to s(CASP) by LE1's own translator); for `birds`, `family`, `abdbirds` and `classic_negation_inconstistent`, the authors of s(CASP) and of s(ASP) (the package names Joaquin Arias, Kyle Marple and Jan Wielemaker as its authors) | Copied unchanged from the s(CASP) package for SWI-Prolog, https://github.com/SWI-Prolog/sCASP: its `test/le_programs` folder, which Jacinto Dávila, an author of LE1, added to the package in April 2022, and its `test/all_programs` folder (`abdbirds.pl` is now in `test/all_programs/sasp/`, among the examples of s(ASP)). The package is under the Apache License 2.0; its `LICENSE` file says "Copyright 2019 Joaquin Arias", and it has no NOTICE file. The files carry no notice of their own. That licence is also the licence of this repository (`LICENSE` at its root), so no second copy of it is kept here. |
| `README.md` | AI agent (Claude, in Claude Code), at Miguel Calejo's request (it came from InsurLE2 with the twins on 16 September 2026 and was rewritten on 23 September) | Written by the agent itself, not by the translator. |
| `MAKING_OF.md` | AI agent (Claude, in Claude Code), 24 September 2026, at Miguel Calejo's request | This file. |

## The record

- Commit `c044cd0` (14 September 2026) "Phase 2c: s(CASP) and Blawx twins", in
  the InsurLE2 repository, by Miguel Calejo with Claude Opus 5 (the commit's
  `Co-Authored-By` line): the translator and the first build. Commit
  `a6daa9a` (15 September) followed a review of the twins.
- The translator moved to the lpsPlus repository, which is private, on 18
  September 2026 (commit `44d3f65` there); the twins moved into this
  repository on 16 September (commit `9d42150`, "move examples"). In November
  2026 the translator was published as open source in this repository, in
  `migration/scasp/` (Apache License 2.0, `migration/README.md`). On 24 November 2026 the line of each ledger that names the translator was
  corrected in place, from the earlier private place to `migration/scasp`;
  nothing else in the twins was edited by hand. Later changes here came from rebuilds
  after translator or writer fixes; the record shows no hand edit of a twin.
- To build the twins again, from the LE2 checkout, with the s(CASP) package
  installed (`pack_install(scasp)`):

  ```sh
  ./myswipl.sh -q migration/scasp/build.pl
  ```
