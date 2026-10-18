# Saving loaded programs to disk

*Kind: plan · Audience: developers · Status: noted for later work, 18 October 2026*

## The problem

Loading a large Logical English program is slow. A DRR twin's scenario file
(for example `lpsPlus/examples/migration/rune/cftc_part45/rates.le`) took
about 150 seconds to load on a development machine, and several minutes on
the fly.io server, whose machine has 1 GB of memory. About three quarters of
that time is parsing, spread across the grammar with no single slow spot. Most
of the rest is the verifier, the check that warns about mistakes in the
program.

A server keeps each loaded program in memory, under a name made from a hash
of its text. So only the first load after each server start is slow. But a
fly.io machine restarts often, and stops when nobody uses it, so in practice
many users meet the slow load.

## The idea

Save the result of a load to disk once, and read it back on later loads.

- **What is saved:** the program's Prolog module (its clauses), and with it
  everything a load writes outside that module: the templates, the source
  texts and line starts of the included files (explanations and "go to line"
  point into them), and the cached Prolog resources.
- **The key:** a hash of the program's text, the hashes of the files it
  includes, and the version of LE2. When any of them changes, the key
  changes and the program is parsed afresh, so a saved copy is never stale.
- **The format:** a Prolog quick-load file (`.qlf`), or a file of terms read
  back with `read_term/2`; to be measured.
- **When the slow parse happens:** once per program and LE2 version, rather
  than once per server start. For the examples that come with the server
  (the DRR twins, the regulatory models), the saved copies can be made when
  the server image is built, so that no user waits; only a program a user
  edits or uploads pays for the parse, once.

## What makes it more than a small change

A load writes some of its results outside the program's module (the
included files' texts and line starts, the Prolog resources). Each of these
must be found, saved and restored, or a program read from disk would answer
correctly but explain badly. The work is to list them all, write them with
the module, and check, on the example suites, that a program read back
answers and explains exactly as a freshly parsed one does.

## Related

- The query of the same file was made faster on 18 October 2026: explanations
  of failed conditions are shortened when they take too long, and a stopped
  query shows the answers it found, with a **Keep going** button (`le_api.pl`,
  `run_answering_query/5`).
