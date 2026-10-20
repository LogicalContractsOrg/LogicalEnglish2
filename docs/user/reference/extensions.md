# Logical English Extensions

*Kind: reference · Audience: users, developers, the assistants (read whole by the LLM features where the extensions are loaded) · Status: current (2026-09-16)*

The constructs on this page operate only where the proprietary `le_extensions.pl`
module is installed. That place is the hosted Logical English (LE) service. Some
servers do not have the module, for example a new copy of this published code.
Such a server cannot read a program that uses one of these constructs. Thus the
program fails before it runs. The module is installed as a symbolic link next to
the LE2 sources. A symbolic link is a substitute file that points to the real file.
Refer to the InsurLE2 README.

The section numbers continue from the language reference
([language.md](language.md) §15). That reference describes three things as parts of
core Logical English. Each server understands core Logical English. The three
things are §15.1 (`only if` rules), the rule labels and provenance of §15.5, and
embedded `prolog` goals (§15.6). Some sections that this page mentions are not on
this page (§2.1, §4, §13, …). Those sections are in the language reference.

## Contents
- [15.2 `which` relative clauses](#152-which-relative-clauses-requires-le_extensionspl)
- [15.3 `unless` inside rule bodies](#153-unless-inside-rule-bodies-requires-le_extensionspl)
- [15.4 Grouped alternatives](#154-grouped-alternatives-either--any-of--at-least-one-of--all-of-requires-le_extensionspl)
- [15.5 Numbered rule bodies](#155-numbered-rule-bodies-requires-le_extensionspl)
- [15.6 Embedded Prolog goals](#156-embedded-prolog-goals-core-le) — core LE, refer to language.md
- [15.7 Prepositional chaining](#157-prepositional-chaining-requires-le_extensionspl)

### 15.2 `which` relative clauses **[requires le_extensions.pl]**
`which` continues a condition with one more clause about the **last variable** of
the condition immediately before it. Thus the writer does not have to write the
name of that variable a second time:
```le
a person is an ancestor of a descendant if
    the person is a parent of a child
    which is an ancestor of the descendant.
```
(In this example, `which` means `the child`.) Rule heads and facts can also have
`which` clauses ("big conclusions"). In **rule heads and facts**, the head keeps
only the words before the first `which`. Each `which` clause becomes one more
condition of the rule:
```le
we will cover a cost
    which is in respect of a damage
    which is caused by a burst pipe
if it is not the case that
    the damage is caused by wear and tear or negligence.
```
The system reads this rule as the conclusion `we will cover a cost`, with the two
`which` clauses as more conditions. A fact that is alone and has `which` clauses
becomes a rule in the same way.

### 15.3 `unless` inside rule bodies **[requires le_extensions.pl]**
Core Logical English has two forms. The first form is `Head if Body unless Condition.`
(§4). The second form is `Head unless Body.`, which has the same meaning as
`Head if it is not the case that Body`. The extension also lets you write `unless`
(or `and unless`) **inside** a body. The `unless` can be on the same line as the
condition that it denies. It can also be at the start of an indented block. In the
two cases, the `unless` has the same meaning as
`and it is not the case that <the negated conditions>`:
```le
we will pay a claim if
    the claim is covered
    and unless
        the claim is fraudulent
        and the fraud is proven.
```

### 15.4 Grouped alternatives: `either:` / `any of:` / `at least one of:` / `all of:` **[requires le_extensions.pl]**
A body line can contain one of these connecting words. Then the line groups the
indented lines below it. `either`, `any of` and `at least one of` join those lines
with *or*. Thus one of the lines is sufficient. `all of` joins the lines with *and*.
Thus each line must be true. `all of` is useful inside an `or` block. Each line
immediately below the connecting word is one alternative, and each alternative can
have its own shape. Thus an `all of` inside an `either` still needs all of its own
lines:
```le
the claimant is eligible for a pension if
    either
        the claimant is poor
        all of
            the claimant is sick
            the claimant has been sick for more than 6 months
            it is not the case that
                the claimant has another form of income
        the claimant has been entitled to a pension previously.
```
In a numbered body (§15.5), an item can deny a condition, for example
`1.2.3. it is not the case that the claimant has another form of income; or`. The
denied condition can be on the line of the item, as in that example. It can also be
in the items with numbers below that item
(`1.2.3. it is not the case that:` followed by `1.2.3.1. ...`).

### 15.5 Numbered rule bodies **[requires le_extensions.pl]**
A rule can have a label, written `rule <name>: Head if ...`. A rule can also have
`with provenance`, which records the source of the rule. The label and the
provenance are parts of core Logical English. Refer to
[language.md §15.5](language.md#155-rule-labels-and-provenance).

When the extension is installed, you can write a rule body that starts with `if:` as
a numbered outline. The numbers of the outline follow the numbers of a statute or of
a clause in a contract:
```le
rule jd:
an A has a relevant asset a B if:
1. the A is affiliated with a C; and
2. the C is connected to a D; and
3. the D owns the B; and
4. either:
4.1. the B is used in the business of the A; or
4.2. all of:
4.2.1. the A is connected to an E; and
4.2.2. the B is used in the business of the E.
```
You can get each numbered condition by its number with
`le_source_element(RuleID, Designator, Goal)`. An example is goal 4.2.1 of rule
`jd`. With the number of a condition, a reader can find the words of the statute or
contract that each clause came from. Refer to
`examples/moreExamples/language/extensions/numbering_test.le`.

### 15.6 Embedded Prolog goals **[core LE]**
`prolog <goal>` conditions in a rule body are part of core Logical English. They do
not need the extensions module now. Refer to [language.md](language.md) §15.6, and
to §14.1 for Prolog resources. Inside a numbered rule body (§15.5), the system reads
a `prolog` item in the same way.

### 15.7 Prepositional chaining **[requires le_extensions.pl]**
§2.1 describes the `; prepositional` template marker and how to use the marker in a
chain. In a chain, you do not write the first argument. Thus one sentence has the
meaning of more than one condition joined by *and*. The extensions module
calculates this chain.
