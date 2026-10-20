# Logical English for LPS: `the target language is: lps.`

*Kind: reference · Audience: users · Status: current (2026-09-20)*

A Logical English (LE) document can declare `the target language is: lps.` Such a
document is a program for **LPS** (Logic Production System). An LPS program has the
timeless rules that all Logical English programs have. An LPS program also tells what
occurs over time:

- **Events and actions** are the things that occur.
- **Fluents** are the facts that stay true from one event until a subsequent event
  changes them.
- **Reactive rules** (`if … then …`, `when … then …`) are the sentences that make the
  program act.

The editor examines such a document for mistakes in the same way as all other
documents. To run the program, use **Run in LPS**. **Run in LPS** needs an LPS2
server. Alternatively, open the program in the LPS2 IDE (Integrated Development
Environment). The LPS2 IDE is the editor in which you write and run LPS programs.

Four built-in templates are only for LPS programs. They are also only for a program
that you will **deploy as a contract**. Three of the four templates set budgets:

- `the gas of *an action* is *a number*`
- `the code size of the contract is *a number*`
- `the call data of *an action* is *a number* bytes`

When you export the program, the system compares each budget with a measurement of
the contract. The fourth template is `the largest whole number is *a number*`. With
this template, a program states the largest number that the target language can
count to. You write all four templates as conditions of a usual
`it must not be true that` sentence. For the four templates, refer to §3.10 of
LPS2's `docs/user/reference/le-for-lps.md`.

LPS2's `docs/user/reference/le-for-lps.md` gives the language one construct at a time.
An LPS2 server shows that document at `/docs/user/reference/le-for-lps`. The example
programs are in LPS2's `examples/le/`. LPS2's `docs/dev/le-lps-interface.md` tells
how LE2 and LPS2 send a translated program to each other.
