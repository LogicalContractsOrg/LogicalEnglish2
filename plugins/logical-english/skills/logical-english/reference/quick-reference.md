# Logical English: a quick reference

The full reference is https://le2.logicalcontracts.com/docs/user/reference/language.md.
This page is the part needed to write a first program.

## The shape of a program

```
the target language is: prolog.

the templates are:
    *a person* gets rent support.
    *a person* is eligible for rent support.
    *a person* is a resident.
    *a person* has an income of *an amount*.
    *a person* is a student.

the knowledge base rent support includes:

a person gets rent support
    if the person is eligible for rent support
    and it is not the case that
        the person is a student.

a person is eligible for rent support
    if the person is a resident
    and the person has an income of an amount
    and the amount < 20000.

scenario ana is:
    ana is a resident.
    ana has an income of 12000.
    support expects answers ["ana gets rent support"].

scenario ben is:
    ben is a resident.
    ben has an income of 25000.
    support expects answers [].

scenario cara is:
    cara is a resident.
    cara has an income of 9000.
    cara is a student.
    support expects answers [].

query support is:
    which person gets rent support.
```

- **Templates**: each place is written `*a type*` or `*an type*`. The words
  around the places are fixed; two places must not touch (write
  `*a person* has *an amount* as income`, not `*a person* *an amount*`).
- **Rules**: `conclusion if condition and condition …`, conditions on indented
  lines. `or` is allowed; when `and` and `or` mix, indent to group them.
- **Facts**: a template with values, ending in a full stop. Facts about one
  case belong in a scenario; facts true for every case (tables, rates) may
  stand in the knowledge base.
- **Queries**: `query NAME is:` and a sentence with `which` in a place
  (`which person gets rent support`), or a condition of several sentences.
- **Expectations**: inside a scenario, `NAME expects answers ["…", "…"].` Each
  answer is the query's sentence with the values found. `[]` expects no
  answer.

## Conditions

| Write | Meaning |
|---|---|
| `it is not the case that` + indented sentence | the sentence cannot be shown |
| `for all cases in which` … `it is the case that` … | every case of the first meets the second |
| `the amount < 20000`, `>`, `<=`, `>=`, `=`, `!=` | comparison of numbers |
| `TOTAL = PRICE * QTY + FEE` | arithmetic; `//`, `mod`, `round(X)`, `floor(X)`, `abs(X)` too |
| `the minimum of A and B is C` | the smaller (also `maximum`) |
| `a date is before another date` (`after`, `before or equal to`) | dates |
| `D2 is 30 days after D1`, `D2 is 6 months after D1` | date arithmetic, either way |
| `X is in LIST` | membership of a list `[a, b, c]` |
| `N is the count of each X such that` + indented condition | counting |
| `T is the sum of each A such that` + indented condition | totals (also `max`, `min`, `average`, `list`) |

## Kinds of thing

```
the ontology is:
    a student is a person.
    a car is a vehicle.
```

## When a fact may be missing

Mark a template `; unknown` when a case may not say it:
`*a person* is a student; unknown.` (the mark goes before the full stop). An answer that needed it then says it rests on that unknown,
instead of failing.

## Questions over every case

```
query support cases is:
    which cases make it the case that
        a person gets rent support.

query student support is:
    is there a case in which
        a person gets rent support
        and the person is a student.
```

`which cases make it the case that …` lists each case in which the goal holds
and the scenarios that cover it. `is there a case in which …` looks for a case
that breaks a property; when there is none, the answer is
`there is no such case: the search covered every case`.
