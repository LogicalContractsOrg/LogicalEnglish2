# Logical English (LE) Syntax Summary

*Kind: reference · Audience: users, developers, the assistants (read whole by the LLM features) · Status: current (2026-09-16)*

This document gives a summary of the constructs of Logical English (LE) that the system understands. A construct is one form of sentence or section of the language. `le_grammar.pl` is the part of the software that reads an LE document. It finds what each sentence says. This document lists the constructs that `le_grammar.pl` accepts.

## Table of Contents
- [Logical English (LE) Syntax Summary](#logical-english-le-syntax-summary)
  - [Table of Contents](#table-of-contents)
  - [1. Document Sections](#1-document-sections)
  - [2. Templates](#2-templates)
    - [Template additions (after `;`)](#template-additions-after-)
    - [2.1 Prepositional templates](#21-prepositional-templates)
    - [2.2 Named constants: `the constants are:`](#22-named-constants-the-constants-are)
    - [2.3 Functions: `the functions are:`](#23-functions-the-functions-are)
    - [2.4 Memorable templates: `; memorable`](#24-memorable-templates--memorable)
  - [3. Rules and Facts](#3-rules-and-facts)
    - [3.1 Rule Sections](#31-rule-sections)
    - [3.2 Query bodies](#32-query-bodies)
    - [3.3 Integrity constraints: `it must not be true that …`](#33-integrity-constraints-it-must-not-be-true-that-)
  - [4. Logical Operators](#4-logical-operators)
  - [5. Aggregates](#5-aggregates)
  - [6. Variables and Constants](#6-variables-and-constants)
    - [6.0 Definite descriptions: back-reference or global constant](#60-definite-descriptions-back-reference-or-global-constant)
    - [6.1 Variable names and types](#61-variable-names-and-types)
    - [6.2 Type checking](#62-type-checking)
  - [7. Arithmetic and Comparisons](#7-arithmetic-and-comparisons)
    - [7.1 Date Handling and Comparisons](#71-date-handling-and-comparisons)
  - [8. Taxonomy (Ontology)](#8-taxonomy-ontology)
  - [9. Ignorable Words](#9-ignorable-words)
  - [10. Comments](#10-comments)
  - [11. Meta-Templates](#11-meta-templates)
  - [12. Testing and Expectations](#12-testing-and-expectations)
  - [13. System Predicates](#13-system-predicates)
  - [14. Included Resources](#14-included-resources)
  - [15. LE Extensions](#15-le-extensions)
  - [16. Humanizing LE](#16-humanizing-le)
  - [17. Regulatory-decision constructs](#17-regulatory-decision-constructs)
    - [17.1 Provenance trailers and judged templates](#171-provenance-trailers-and-judged-templates)
    - [17.2 `otherwise` cascades](#172-otherwise-cascades)
    - [17.3 Decision tables](#173-decision-tables)
    - [17.4 The decision skeleton: applicability, question, remedy](#174-the-decision-skeleton-applicability-question-remedy)
    - [17.5 Source-scoped proof: `according to` in a rule](#175-source-scoped-proof-according-to-in-a-rule)
    - [17.6 Services and semantic predicates over text](#176-services-and-semantic-predicates-over-text)
    - [17.7 Flip queries: which minimal change flips the outcome](#177-flip-queries-which-minimal-change-flips-the-outcome)
    - [17.8 Factors and precedent: a pattern, not syntax](#178-factors-and-precedent-a-pattern-not-syntax)
    - [17.9 Facts from a document](#179-facts-from-a-document)
    - [17.10 Views: how a screen shows a program](#1710-views-how-a-screen-shows-a-program)
    - [17.11 Case searches: every case, and properties](#1711-case-searches-every-case-and-properties)

## 1. Document Sections
You write a program in sections. Each section tells the system how to read the sentences that follow it. Each section header ends with a colon `:`.

- **Included Resources:** `the knowledge base <name> includes these resources:` or `the contract <name> includes these resources:`. This section brings in other LE files, or documents at a web address. (A web address is also known as a URL.) Write this section before the main knowledge base header.
- **Knowledge Base:** `the knowledge base <name> includes:` or `the contract <name> states that:`
- **Scenario:** `scenario <name> is:`. This section states the facts of one case. Usually, it is a case that you use to test the program.
  - A scenario can include expectations: `<QueryName> expects answers [<List of Strings>] and unknowns [<List of Strings>].` You can omit the word `answers`. With `and any unknowns`, the test checks only the answers (§12).
- **Query:** `query <name> is:`. This section says what the program must try to prove. The
  body of a query can be a **full condition, the same as the body of a rule**. It is
  not necessarily one sentence: the body can join conditions with `and`, `or`,
  negation (`it is not the case that …`) and `for all cases in which …` (refer to §3.2).
- **Ontology:** `the ontology is:`. This section says which kinds of thing are kinds of other things.
- **Templates:** `the predicates are:` or `the templates are:`. This section gives the sentence patterns of the program.
- **Constants:** `the constants are:`. This section gives named values, one on each line: `the fee is 5.` (§2.2).
- **Functions:** `the functions are:`. This section gives templates of the form `... is *a value*`. You can write the value of such a template without its last place (§2.3).
- **Bases (LPS target):** LPS is Logic Production System. LPS is the companion system for rules about time and change. `the knowledge base <name> extends <base>, <base>.` brings in the templates, laws and constraints of the bases, but not their instance (`le_lps_surface.md` §1.1).
- **Dynamics:** `the fluents are:` or `the events are:`. These sections are for reasoning about time. In the LPS target, a sentence needs times only where it relates two moments. An example is `if there is a fire in a room and it is not the case that an alarm is on then an alarm goes on.` This sentence reads its conditions at one time, and it starts its action at that time. The sentence `when an alarm goes on then an alarm is on.` also needs no times (`le_lps_surface.md` §3.1).
- **Meta:** `the target language is: prolog.` This line is necessary before the system can make Prolog.

## 2. Templates
A template is a sentence pattern. Each template says how you can write one kind of sentence. The template also connects that kind of sentence to a predicate in the Prolog program that the system makes from Logical English. A predicate is a named relation.
- **Pattern:** `*a person* is a friend of *another person*`
- **Variables:** Words between asterisks `*...*`.
- **Types:** The **head noun** of the variable phrase (for example `person`). Refer to §6 for how the system separates names and types.
- **Variable Scoping:** If you write the same variable name two times in one sentence, or in one query, the two names refer to the same individual.
  - `which person is the father of which person` matches only when a person is the father of himself.
  - Use `which person is the father of which other person` to refer to two different persons.

### Template additions (after `;`)
After a template definition, you can write one or more additions. Each addition starts with `;`:
- `; opposite: <template>` — this addition declares how to say the opposite of the template. A rule can then conclude the opposite form, and an explanation can show it.
  **The opposite form is not a negation when you use it as a condition.** As a condition, `the claimant does not have another form of income` asks about a separate relation. Only a rule that concludes that relation can prove it. Such a rule is an `only if` rule (§15.1). To test that the positive template is not true, write `it is not the case that the claimant has another form of income`. The verifier reports an opposite form that a condition uses but that nothing concludes (`opposite_as_condition`).
- `; synonym <template>` — this addition declares a **second way to say the same thing**. The synonym is for the **same** relation as the main template. Thus you can write a fact, the head of a rule, a condition of a rule and a query in each of the two forms. A template can have several `; synonym ...` additions, one after the other. The system matches the `*variables*` of the synonym to the variables of the main template **by position**. Thus the two forms must list their arguments in the same sequence.
  - Example: `*a payment* is in respect of *a claim*; synonym *a payment* covers *a claim*.` The fact `p covers c` is the same fact as `p is in respect of c`.
  - **Rendering:** By default, the system shows the main form, that is, the form that you wrote first. An explanation shows each step in the form that the rule or fact that proves the step uses. A query shows its answers in the form that the query uses.
  - **Restriction:** a template with a synonym **cannot have other additions** (`opposite`, `prepositional`, `unknown`, `undefined`). The system reports such a template as a `synonym_with_other_additions` error.
- `; prepositional` — this addition marks a **prepositional** template (refer to §2.1). The synonym `; composite` has the same meaning.
- `; unknown` — this addition marks the template as **assumable**. When the program cannot prove a sentence of this kind, the system assumes that the sentence is true. The system reports the sentence as an unknown. The integrity constraints set the limits of this assumption (§3.3). Logicians call a sentence that the system can assume in this way an abducible. The synonyms `; assumed` and `; assumable` have the same meaning. When the scenario proves a sentence already, the system does not also assume the sentence. **A useful negation of such a sentence is not possible:** `it is not the case that` before the sentence is never true. The reason is that the system never proves false a sentence that it can assume. To require that something is *not* true, and keep it open, declare that requirement as a separate template (`*a counterparty* is not in administration; unknown.`). The verifier reports a negated unknown (`negated_unknown`).
- `; undefined` — this addition marks the template as a **scenario element**. Sentences of this kind are only for scenarios. They are never facts or conclusions of rules in the knowledge base. The synonym `; scenario element` (two words) has the same meaning. The verifier then changes its operation for the template in two ways:
  - The verifier does **not** give its `undefined_predicate` warning for this template, although the knowledge base has no rule and no fact for it.
  - The verifier gives a **`defined_scenario_element` warning** when it finds a fact, or a rule that concludes this template, in the knowledge base.
  - Example: `*a person* has passed the test; undefined.`
- `; via service <name>` — a declared service answers the template when the query runs (§17.6).
- `; <value> by default` — **LPS target, fluents only** (`le_lps_surface.md` §2). This addition gives the value of the last place of the template where no fact has stored a value (`the balance of *an account* is *an amount*; 0 by default`, `…; the zero address by default`). The system reports a default on a different template (`default_not_lps`).
- `; judged` — this addition marks an **open-textured** relation. A person *decides* the instances of such a relation; rules do not calculate them. The synonyms are `; open textured` and `; evaluative`. The system solves a judged template as it solves `; assumable`, with one difference. When a question has a recorded outcome (the last argument), the system assumes no other outcome for that question. A rule that concludes a judged template is an error. The system shows an instance that nobody decided yet as *judgment needed*. Refer to §17.1.
- `; memorable` — while a query runs, the system **keeps** the answers to this template. It calculates each different question one time only, and keeps the answers and their explanations. Each time that the same question occurs again, the system gives the same answers (§2.4). The name of this method is memoization. The synonyms `; memoised`, `; memoized` and `; cached` have the same meaning.
- `; one value` — the **last place of the template holds one value** for each choice of its other places. For example, mark *the income of a person is an amount* with `; one value`, and a person has one income. The synonym `; single valued` has the same meaning. Only the case search reads this marker (§17.11). The case search reads two facts of such a template about the same things as one fact. Thus a case never needs a person with two incomes, or a report with two reporting parties. Queries give the same answers as before, and a scenario that states two values still has the two values. Rune is the language of the Common Domain Model of ISDA. The translator of Rune marks with `; one value` each attribute that Rune lets have only one value.
- `; image "<address>"` — this addition gives a **picture** for a sentence. The **Bento Box** shows the picture in the location of the sentence. The Bento Box is the editor display of an explanation as boxes in boxes (refer to §12 of the [introduction to LE](../tutorials/intro-to-le/intro-to-le.md#12-bento-box-an-explanation-as-boxes-in-boxes)). The address is a full web address that starts with `http://` or `https://`, in double quotes. The picture has no effect on what the program proves. You can write the addition in two locations:
  - **On a scenario fact**, before its full stop: `pad one is a pad on step grid; image "https://…/drum.png".` The picture is for that fact. The fact must be **concrete**, that is, it must have no variables.
  - **On a template with no variables** (a template whose sentence has no `*…*` place): `the power is on; image "https://…/plug.png".` The picture is then for that sentence in all locations where no fact has a picture of its own.
  - **Warnings:** the verifier reports a picture on a fact with variables (`image_nonground`), on a rule (`image_on_rule`), and on a template with variables (`image_template_vars`). It also reports an address that is not a full web address (`image_bad_url`). In each of these cases, the system ignores the picture, and the program runs as before.
  - The keyword is in the language of the document: `imagem` (Portuguese), `imagen` (Spanish), `image` (French), `immagine` (Italian).
  - Refer to `examples/moreExamples/domains/other/sequencer.le`.

### 2.1 Prepositional templates
A prepositional template relates two things, and it **starts with one of the two things**. Thus it can extend the condition before it. In a chain of such templates, the author can omit the first argument. The system then adds that argument from the previous condition: it uses the variable whose type agrees.
- **Declaration:**
  ```le
  *a payment* under *a policy*; prepositional.
  ```
- **Constraints:** the template must have exactly two `*variable*` arguments, and its first word must be a `*variable*`. The system reports a template that does not obey these rules as a `prepositional_arity` or a `prepositional_first_arg` issue.
- **Chained usage** (without the first argument; the chain needs `le_extensions.pl`, [extensions.md](extensions.md) §15.7):
  ```le
  we will make a payment under this policy in respect of a claim
  ```
  The system expands this text to the conjunction
  ```le
  we will make a payment
  and the payment under this policy
  and the payment in respect of a claim
  ```
  Each prepositional template becomes an **extra condition** of the rule. This is true when the chain is in the head of the rule, and also when the chain is in its conditions.
- **Standalone usage** is also possible: write the first argument (for example `the payment under this policy`), and the sentence matches the template directly.

### 2.2 Named constants: `the constants are:`
This section gives named values, one on each line, in the form `<name> is <value>.`:
```le
the constants are:
    the tax free allowance is 12570.
    the unlimited allowance is 115792089237316195423570985008687907853269984665640564039457584007913129639935.
```
The name then has the meaning of the value in each rule, scenario or query that
uses it: `a person pays tax if the person earns an income and the income > the tax free allowance.`
An explanation shows the value as a reason.

Each line declares the template `the value of <name> is *a <type>*`, and states
the one fact of that template. Thus you can also put the value into a variable:
`the value of the tax free allowance is an allowance A`. You can also write the name
in arithmetic, as in `the tax is (the income - the tax free allowance) * 0.2`
(§2.3 tells how the system reads the operands).

A variable of a rule is stronger than a constant with the same name. In this
program, `the rabbit` in the rule is the rabbit that `A rabbit` introduces, not
`jonas`:

```le
the constants are:
    the rabbit is jonas.

the knowledge base rabbits includes:
    A rabbit is happy if the rabbit has baby rabbits.
```

The name has the meaning of the constant only in a rule that does not introduce a
variable with that name, for example
`a creature is happy if the rabbit has baby rabbits.`

The system finds the type of the value from the value as you wrote it: a number, a
piece of text, or a name. The name itself can contain the word `is`. Then the value
is the part after the last `is`. The verifier reports a constant that nothing uses
(`unused_constant`). `le_writer.pl` is the part of the software that writes an LE
program out again. It writes the section again from the item `constant(F, Name, Value)`.

A constant is a special case of a **function** (§2.3): its value is written, not
calculated. When the rules calculate the value, use the functions section.

### 2.3 Functions: `the functions are:`
A **function** is an ordinary template of the form `... is *a value*`. Its last
place, after the word `is`, is the value that the function gives. You declare a
function in a separate section:
```le
the functions are:
    the price of a cup with capacity *a number* ml is *an amount*.
```
When you declare the function, you can write the sentence **without its last
place** in each location where a value is necessary. Thus these two conditions

```le
    and the price of a cup with capacity the capacity ml is a price
    and the price > 10
```

can become one condition:

```le
    and the price of a cup with capacity the capacity ml > 10
```

Nothing else changes. The full sentence continues to operate. An ordinary rule or
fact defines the function (`the price of a cup with capacity a number ml is an amount if the amount is the number / 10.`).
A function can also be a relation with **several answers**. Then each sentence that
uses the function also has several answers. When one sentence uses the same function
two times in the same way, the system asks the question **one time**. Thus the
repeated phrase does not multiply the answers.

A function with no place of its own is a value with a name. An example is
`our policy is *a policy*`, used as `our policy`. Before, the `; defines global`
addition had this purpose. The system does not have that addition now. A value
that you write is a constant (§2.2). A value that the rules calculate is a
function. The name of a function is the words of its sentence, not a separate
invented name. When a program still has `; defines global`, the system tells you so
at that line (`defines_global_removed`).

Important details:

- **Where you can write it.** In each location where a value is necessary: a
  comparison, an `is`, a place of a different template, or the value of the head of
  a rule (`the label of thimble is our currency.`). A fact whose value is the value
  of a function is a rule.
- **Arithmetic.** You can write the function as an operand of arithmetic (an
  operand is a value that `+`, `-`, `*`, `/` or `mod` operates on), as in most
  programming languages: `the total is the price of a cup with capacity 200 ml + 5`.
  You can write a constant (§2.2) in the same way. These rules apply:
  - The operand is all the words and numbers up to the next operator. Thus the
    function operates first: `the double of the price of the cup + the fee` is the
    double of the price, plus the fee.
  - To give the function a calculated value, put the value in brackets:
    `the double of (the fee + 1) - 1`.
  - A function can be the value of a place of a different function:
    `the double of the price of a cup with capacity 200 ml`.
  - A variable of the rule is stronger than a constant or a function with the same
    name, as in §2.2.
  - The name of a variable in arithmetic must still be an id (§7).
- **Nothing can follow the phrase where the sentence continues with `is`.**
  `the price of the cup > 10` is correct, and `the label is our currency` is also
  correct. But `the price of the cup is in [10, 20]` is not correct. The sentence of
  the function matches from the start, and it reads `in [10, 20]` as its value. For
  these forms (`is in`, `is equal to`, `is a`, or a template that starts with the
  place that you fill), put the value into a variable in a separate condition.
- **The condition goes first.** The system puts the question that asks the function
  for its value before the condition that uses the value. Thus a comparison can
  operate.
- **The system checks the form.** The verifier reports a line of the section that
  does not have the form `... is *a value*` (`function_not_is_form`). That line
  stays an ordinary template.
- **LPS.** The same section, with the same meaning, is available with
  `the target language is: lps.` (`/lps2/examples/le/functions.le`). A fluent, an
  event or an action keeps its own declaration section, because that section gives
  it its LPS role. Thus you must still write the value of a fluent in full.
- **The writer** changes a program back into LE text. It writes the section again
  from the item `function(F, Text)`. When the program uses a value after its inputs
  are known, the writer writes the function in the short form. The translators from
  other systems also make this form.

The worked example is
`examples/moreExamples/language/templates/functions.le`.

### 2.4 Memorable templates: `; memorable`
A query on a large program frequently proves the same thing many times. Several
rules, or several cases of one rule, reach the same condition with the same values.
After the query, the explanation shows the repetition: it puts the repeated parts
together. The `; memorable` addition prevents the repeated work itself, for the
templates that the author selects:
```le
the templates are:
    *an ancestor* is an ancestor of *a person*; memorable.
```
- **What the system keeps.** In one query, the program asks a *different* question
  of the template for the first time. Then it calculates **all** the answers to that
  question, each with its unknowns and its explanation. A later question can be the
  same, with only different names for its variables. The system answers such a
  question from what it kept. An example is `which ancestor is an ancestor of Lettice`
  again. But `is Owen an ancestor of Lettice` is a different question. The system
  identifies a question that it answered before by a short code. It calculates this
  code from the shape of the question.
- **The system uses again only completed questions.** The system keeps a question
  when it has calculated all the answers. Sometimes the check against endless loops
  (below) stops the work on a question, because of a question *outside* it. Then the
  system does not keep the question. Its answers are then correct only in the
  location where the program asked it. The next time, the system calculates the
  question again.
- **Recursion through a value that is not known yet.** (Recursion is a rule that
  uses itself.) Without the marker, the system prevents a rule that uses itself
  without end. It refuses a condition that is the same as a condition that it proves
  at that time, in the form that the condition had when its proof started. An example
  is `the obligation starts on a day`, asked during the proof of
  `the obligation starts on a day`. Thus a rule such as
  ```le
  the obligation starts on a day if
      the obligation starts on an earlier day
      and a person pays on the day
      and the day > the earlier day.
  ```
  finds the days that follow the first day of the obligation, but not the days that
  follow those days. When you mark the template with `; memorable`, the system answers
  the same question inside its own work from the answers that it found until then.
  The system repeats the work, round after round, until a round finds no new answer.
  The question then has all its answers: each day that follows an earlier day.
  (Logicians call the result the least fixpoint. When the recursion goes through
  `it is not the case that`, the rounds possibly do not become stable. Then the system
  stops after 200 rounds, and it does not keep the answers.)
- **Same answers, same explanations.** The recursion above is the only case where
  the marker finds answers that the plain rule cannot find. In all other cases, the
  marker changes when the system does the work, not what the system concludes. A
  question that the system answers from what it kept gives the answers
  of the first time, in the same sequence. Its explanation is the same
  proof. Thus the editor puts repeated explanations together, as usual.
  When such a question has no answer, the system reads two things from the first
  time: the explanation of the failure, and the alternatives that it tried until
  none was left. There is one difference. The first time, the system calculates all
  the answers before it uses the first answer. Thus a query that stops early (with
  `once`, or with a time limit) does all that work at the start.
- **Long chains.** A chain of kept questions, each answered from the question before
  it, is not a proof without control. An example is the 360 monthly payments of a
  loan, where each balance comes from the balance of the previous month. The system
  proves each link of the chain one time. A proof without control stops at a limit
  of 100 conditions inside one another. The system starts this count again inside
  each kept question. The limit for such chains is 5,000 kept questions inside one
  another.
- **Explanations of long chains.** When an explanation has a maximum of 150 steps,
  the system keeps all of it. Otherwise, the system keeps its first levels: as many
  levels as keep it at that size. Without this limit, a chain of instances that read
  each other makes an explanation that grows exponentially with the length of the
  chain. The explanation shows the reasons of each link where the program asks that
  link. In an explanation, a list of more than 12 items shows its first 10 items and
  the number of items.
- **For each query, not for each session.** The system forgets the kept answers when
  a query starts. The facts of a session change between queries: for example, you
  set a scenario, or a flip query tries changes. An answer that the system calculated
  with different facts can be incorrect. In one query, some proofs occur inside a
  different proof: a why-not attempt, a section check, a constraint check of an
  assumption, a flip. Each such proof keeps its own answers separately. A scoped
  proof (`according to`, §17.5) also keeps its own answers.
- **When it is useful.** The marker is useful for a template that the program asks
  many times with the same arguments, and that has a slow proof. Examples are a count
  that uses itself, a classification that many rules use, and a relation that the
  system builds from facts step by step. A template that the system only finds in a
  table of facts gets no benefit, and the system must still calculate the code of
  each question. To select the templates, look at the repeated explanations that the
  editor shows.
- **Warnings.** The verifier reports:
  - `memorable_under_negation`: a memorable question asked under
    `it is not the case that`, under `unless`, or in the guard of `otherwise`. A
    negation stops at the first answer. But a memorable question calculates all the
    answers before it gives the first answer. Thus the work has no value, unless the
    program also asks the same question outside a negation;
  - `memorable_calls_prolog`: a rule of the memorable relation runs an embedded
    `prolog` goal (§15.6). A goal can change something that the program does not see.
    Then the kept answers are out of date, and nothing finds the problem.
- **Only for the Prolog target.** The part that answers queries for the Prolog
  target reads the marker. The s(CASP) and LPS targets ignore it. The writer keeps
  the marker when it writes the program again.

Refer to `examples/moreExamples/language/memoization/` (`lattice_paths.le`,
`family_relatives.le`, `memorable_warnings.le`).

## 3. Rules and Facts
- **Fact:** a plain statement that ends with a full stop.
  - `Alice is a person.`
- **Rule:** a statement with a head and a body. The head is the conclusion. The body gives the conditions.
  - `Head if Body.`
  - `*a person* is eligible if *a person* is a citizen.`
- **Unknown Fact:** a statement that says that one specific sentence of a template is unknown. You can put such a statement in the knowledge base, where it applies to all scenarios. You can also put it in one `scenario` section.
  - `it is unknown whether *a payment* is in respect of claim 01.` This statement sets the second argument to 'claim 01', and it keeps the first argument open. The synonyms `it is assumed whether ...` and `it is assumable whether ...` have the same meaning.
- **Negated Fact:** in a `scenario` section, a statement that one sentence of a template is *not* true: `it is not the case that`, followed by the sentence.
  - `it is not the case that portsmouth water limited is outside the water undertaker class.`

  While the scenario is loaded, the system does not prove the sentence and does not assume it. This is also true when the template has the `; unknown` addition. With such a statement, a scenario says that a finding had the opposite result. Outside a scenario, such a statement is an error (`negated_fact_outside_scenario`). In a rule, `it is not the case that` stays a condition (§4).

### 3.1 Rule Sections
You can put the rules of a knowledge base into named **sections**, but this is not necessary. A section marker is a line of this form:
```le
section <name> is:
```
Each rule, and each fact, that follows the marker is in the section `<name>`, until the next marker. The system records the section of each rule in `le_source_section/2` (refer to §13). A section does not change how the rules operate when the system answers a query. A section name is only a label.

Conventions:
- When a knowledge base has no section markers, all its rules are in the default section **`main`**.
- The names **`applicability`**, **`question`** and **`remedy`** are reserved for the decision skeleton (§17.4). The three names do not change how the system answers a query. But when a query fails, the system reports the failure against these names.
- The rules before the first section marker are also in **`main`**.

There is a short form for a frequently used section with the name `annexes`:
```le
the annexes to the contract are:
```
This line is exactly the same as `section annexes is:`. The synonym `the annexes to the knowledge base are:` has the same meaning.

Example:
```le
the knowledge base example includes:

a customer is preferred if the customer is loyal.   % belongs to section 'main'

the annexes to the contract are:

rule extra:
a customer is loyal if the customer is old.         % belongs to section 'annexes'
```

### 3.2 Query bodies
The system reads the body of a `query <name> is:` section **exactly as it reads
the body of a rule**. The body is a full condition, and not necessarily one
sentence. The body can join conditions with the operators of §4:

- **Conjunction / disjunction** with `and` / `or`. The conditions share their
  variables. Thus the same name refers to the same individual:
  ```le
  query both is:
      a person is happy
      and the person is healthy.
  ```
- **Negation** with `it is not the case that …`. As in the body of a rule, the
  negated goal goes on a separate indented line:
  ```le
  query safe is:
      a person is happy
      and it is not the case that
          the person is sad.
  ```
- **Universals** with `for all cases in which … it is the case that …`. Use the
  same indented shape as in rules (refer to §4 and `examples/.../subset.le`):
  ```le
  query all_happy is:
      for all cases in which
          a person is a dragon
          it is the case that
          the person is happy.
  ```

Usually, a query is one sentence, for example `which dragon is happy.` Such a query
operates as before. For a query of several conditions, the system writes each answer
from the words of the query, with the values that it found for the variables:
`"bob is happy and bob is healthy"`.

> The layout rules of the body of a rule also apply here. A negated sentence, and
> each part of a `for all cases`, must be on a separate indented line. Possibly you
> write all of `… and it is not the case that the person is sad` on one line. Then
> the system does **not** separate the negation. Rule bodies have the same limit.
> Thus put the negated sentence on the next line.

### 3.3 Integrity constraints: `it must not be true that …`
An **integrity constraint** says that some conditions must never be true at the same
time. Another name for an integrity constraint is a *denial*. You write a constraint
in the knowledge base. It is similar to the body of a rule, but nothing is concluded
from it. The same sentence is correct in all target languages:
```le
it must not be true that
    a person is resident in a country
    and the person is resident in a second country
    and the country is different from the second country.
```
- **Prolog target**: a constraint checks what an answer **assumes**, that is,
  the templates that have the `; unknown` addition in §2. Reasoning that assumes what
  it cannot prove has the name abductive logic programming. The system does it as
  follows. Sometimes the system finds an answer because it assumes something. The
  system keeps such an answer only when the case agrees with all constraints. For
  this check, the system takes the assumptions as true, and it assumes nothing else.
  During the check, the system takes as false each thing that is not stated and not
  assumed. Thus a constraint can use `it is not the case that`.
  - Sometimes the negation of an assumable thing breaks a constraint. Then the
    system **repairs the answer with more assumptions**. An example is the
    constraint `it must not be true that a person is married to a second person and it is not the case that the second person is married to the person`.
    When the system assumes that dan is married to erin, it then also assumes that
    erin is married to dan. The answer lists the two unknowns.
  - In all other cases, the system **rejects the answer**. With the first
    constraint above, the system cannot assume that alice, who lives in Spain, is
    resident in France. Thus the system does not give alice as a person who pays tax
    in France.
  - Sometimes the **facts** of a case break a constraint without an assumption, and
    no assumption can repair the case. Such a case is **inconsistent, and nothing
    follows from it**. Then no query has an answer. The explanation of the empty
    answer is the constraint, together with the proof of its conditions ("the case
    breaks a constraint …").
  - Constraints do not change other things: ordinary `if` rules, queries, and the
    definite answers of consistent cases. A program with no constraints operates
    exactly as before constraints existed.
- **s(CASP) target**: the system writes each constraint as a global
  constraint, `false :- Conditions.`. Each model must agree with this constraint.
  Thus each set of assumed sentences (`#abducible`) must also agree with it. A
  caution: s(CASP) 1.1.4 gives incorrect results for one kind of constraint. That
  kind of constraint still has open variables, and it uses `is different from`
  together with assumed sentences. The system operates correctly on a constraint
  whose values are all fixed.
- **LPS target**: the same sentence is an LPS constraint on actions and states
  (`d_pre/1`, `le_lps_surface.md` §3.7). In LPS, actions and events are the
  abducibles. The reactive engine and the planner never select an action that
  breaks a constraint.

Refer to `examples/moreExamples/language/unknowns/assumption_constraints.le`. Some
translators bring s(CASP) and Prolog programs into LE (`le_writer:prolog_to_ir/3`).
These translators read a denial, `:- Body.` or `false :- Body.`, as a constraint of
this kind.

## 4. Logical Operators
- **And:** `and` (or a new line with the same indentation)
- **Or:** `or`; grouped alternatives `either`, `any of`, `all of` ([extensions.md](extensions.md) §15.4)
- **Which operator applies first:** the system reads the lines at the same
  indentation from the top. Its own connective joins each line to all the lines
  above it. Thus
  ```le
  a person is eligible
      if the person is a resident
      or the person is a citizen
      and the person is an adult.
  ```
  means (resident or citizen) and adult: the `and` line applies to the two
  alternatives above it. A reader can think that it means resident or (citizen and
  adult). Thus the verifier gives a warning each time that an `and` line follows an
  `or` line at the same indentation. Use the indentation to show the meaning that you
  intend. Then the warning stops:
  - for resident or (citizen and adult), indent the `and` line below the `or`
    line that it is part of;
  - for (resident or citizen) and adult, indent the `or` line below the line
    that it is an alternative to, and do not move the `and` line.

  An `or` line that follows an `and` line causes no warning: `a` / `and b` /
  `or c` means (a and b) or c, as most readers expect.
- **Otherwise:** a line that starts with `otherwise` starts a new alternative. That alternative applies only when all the earlier alternatives fail (§17.2).
- **According to:** `<condition> according to <source>` proves the condition only from the evidence of that source (§17.5).
- **Negation:** `it is not the case that` or `not the case that`
  - `it is not the case that *a person* is a citizen`
  - `not the case that *a person* is a citizen`
- **Conditional Negation:** `unless`
  - `Head if Body unless Condition.` (The same as `Head if Body and not Condition.`)
- **Universal Quantification:**
  ```le
  for all cases in which
      <condition 1>
      <condition 2>
  it is the case that
      <consequence>
  ```

## 5. Aggregates
An aggregate calculates one value from a full set of answers.
- **Operators:** `sum`, `count`, `average`, `min`, `max`, `list`
- **Syntax:** `<ResultVar> is the <Op> of each <Var> such that <Goal>`
- **Example:** `*Total* is the sum of each *Amount* such that *the account* has *Amount*`
- **Lists:** `L is the list of each A such that the customer pays A` gives the
  answers themselves, as a list. The values stay in the sequence in which the
  system finds them. This is the sequence of the facts and rules that give them. When
  the system finds a value two times, the value is in the list two times. The list of
  nothing is the empty list, `[]`. An answer shows a list with commas between its
  values: `[50, 20, 50]`. (In other languages: `a lista de cada`, `la lista de cada`,
  `la liste de chaque`, `la lista di ogni`.) Refer to
  `examples/moreExamples/language/aggregates/lists.le`.
- **Nothing to aggregate:** when no answer agrees with the goal, the sum and
  the count are 0, and the list is `[]`. The minimum, the maximum and the
  average of nothing do not exist. Thus the condition fails, and the rule gives
  no answer. (Before 29 September 2026, these values were 0. Thus "the first
  payment after the deadline" was time 0 when there was no such payment.)
- **Scope:** the conditions of `such that` are the lines that are indented below it.
  A line at the level of the aggregate itself (`and N > 3`) is a condition that
  comes after the aggregate. The same is true where the aggregate is the first
  condition, on the line of the header
  (`the total is large if N is the sum of each I such that`, and in LE for LPS
  `if … then` and `when … then`). It is also true in a query section, whose body
  can start with an aggregate:
  ```le
  query total is:
      a number N is the sum of each I such that
          a person pays I
      and N > 12.
  ```
- **Name the thing first.** Examine
  `the capped amount for a claim component is an amount P if P is the max of each V such that the payable benefit for the claim component is V`.
  Here, no condition before the aggregate says which claim component. Thus the
  aggregate uses the benefits of all components together, and the rule gives one
  answer, for no specific component. Name the component first:
  `if a claim has the claim component and P is the max of each V such that ...`.
  The verifier gives a warning for the first form (`unbound_aggregate_variable`).
- **Answers and explanations** show an aggregate as a sentence, with the value
  that the system found and the conditions:
  `15 is the sum of each I such that a person pays I`. When a noun names the thing
  that the aggregate counts or adds, the sentence uses `the <noun>` in those
  conditions: `2 is the count of each amount such that bob owes the amount`.

## 6. Variables and Constants
- **Variables:**
  - Explicit: `*my variable*`
  - Implicit: `a person`, `some person`, `each person`, `which person`, and also
    `the person`, but **only as a back-reference**: refer to §6.0.
  - Special: `who`, `what`, `when`, `where`

### 6.0 Definite descriptions: back-reference or global constant
An **indefinite** phrase (`a person`, `an amount`, `some rabbit`) *starts* a
variable. A **definite** phrase (`the person`, `the white rabbit`) never starts a
variable. A definite phrase is a variable only when the *same sentence* started a
variable with that name before. Otherwise, the definite phrase is the name of a
**global constant**. A global constant is the one individual that the phrase refers
to, written with its article (`the white rabbit`). It is the same individual in all
rules, scenarios and queries of the program.

```le
a rabbit is in a hurry
    if the rabbit is late for an appointment.       % "the rabbit" = the head's variable

a person falls down the rabbit hole
    if the person follows the white rabbit          % "the white rabbit" = a constant,
    and the white rabbit is late for the tea party. % and so is "the tea party"
```
The second rule is about **one** rabbit. A scenario fact
`the white rabbit is late for the tea party` is about the same individual, because a
definite phrase in a scenario was always a constant. Refer to
`examples/moreExamples/language/templates/white_rabbit.le`.

Important results of this rule:
- The sequence in a sentence is important, not only the presence of the name. The
  phrase that starts the variable must come first. The system reads the head of a
  rule before its conditions, and it reads the conditions from left to right. LE is
  usually written in this sequence.
- A back-reference with an incorrect spelling (`the peron`) does not become a
  variable now. Before, such a variable matched all things without a message. Now
  the incorrect spelling becomes a constant that no other part of the program uses.
  Thus the rule never applies.
- To use a definite phrase as a variable that nothing starts, name it
  explicitly: `*the white rabbit*` (§6.1).

### 6.1 Variable names and types
A variable phrase can have a **name** and a **type**. Thus you can identify several variables of the same type:
- **Type** = the **head noun** of the phrase. The full phrase is the **name** of the variable. The name tells the system if two phrases are about the same thing. The system also shows the name on the screen.
- **Leading qualifier:** an ordinal (`first`, `second`, …, `tenth`), or one of `other, another, new, previous, next, current, last, same, original, single, given`, before the noun. A qualifier marks a variable of the same type, but different from the other variables. Thus `a first person` and `a second person` are **two different variables, and the two have the type `person`**. The system accepts a `person` value in each of the two places.
  - `*a first person* greets *a second person*`: two `person` arguments. Refer to `examples/moreExamples/language/templates/named_vars.le`.
- **All-caps id convention:** a short name at the end is the name of the variable. The name is one capital letter, or a short word in capital letters. The noun or nouns before the name are the type. `a person X` and `a person Y` are two different variables of type `person`. The same is true for `a number N` and `a date D`.
- **Real multi-word types** (with no leading qualifier and no id at the end) stay complete. For example, `a bodily injury` has the type `bodily injury`, and `a repair cost` has the type `repair cost`.
- **A maximum of five words.** After the article, a maximum of five words is possible. A leading qualifier is not in this count. Thus `a second final contract signatories party list` is a variable (the qualifier `second` and five words of type). The system reads a longer phrase as words, that is, as a constant.
- When the *same* phrase occurs again (`a first person` … `the first person`), it refers to the same individual, as in §2.

### 6.2 Type checking
The system uses the **type** of a variable (§6.1) to reject values that are not of that type. The check occurs **late**: it occurs when the argument has a value. The check is also **tolerant**: it rejects a value only when there is a clear conflict. It always accepts a value whose type is unknown. The system looks for `is_a` facts in the **knowledge base**, and also in the scenario facts of the current **session**.

- **Instance values.** A value has a known type when an `is_a` fact gives that type. A scenario fact such as `this payment is a payment` is also such a fact. The system accepts such a value in a place of type `T` only when the value *is a* `T`. This can be directly, or through the `is_a` taxonomy, or because the head nouns are the same. Thus the system **rejects** a value that is declared a `payment` in a place for an `amount`. The system accepts a value with **no** known type in all places.
- **Type values.** A value can itself be a *type*, as in taxonomy reasoning (`*sub* isa *super*`). Such a value must be a sub-type of the type of the place. But this is necessary only when the type of the place is part of the ontology, that is, when something is a `T`, or `T` is a something. Examine a placeholder type such as `super`. Nothing is a `super`, and `super` is not above or below a different type. Such a type has no requirement for the value. Thus the system accepts a real type such as `dragon` in that place.
- **Universal types.** `any`, and the universal types `thing`, `object`, `entity`, `asset`, `element`, accept all values.
- **Separate the rules that conclude the same relation.** Sometimes the heads of two rules conclude one relation, but they declare **different argument types**. Then the type keeps the rules separate. For example, examine these two prepositional bridges:
  ```le
  a payment in respect of a claim if the payment is in respect of the claim.
  an amount  in respect of a claim if the amount  is in respect of the claim.
  ```
  The fact `this payment is in respect of this claim`, together with `this payment is a payment`, matches **only** the first rule. The reason is that the head of the second rule rejects `this payment`, because that head asks for an `amount`. The system checks the head of a rule in this way **only when the templates do not agree** about the type of a place. Here, the first argument is a `payment` in one template and an `amount` in the other template. When the templates agree, the type cannot identify one rule from the other. Thus the system does not check the head. A single `affiliate` template is an example: a `company` can correctly operate as an `affiliate`.

In an explanation, the system shows a type check as the statement that it checks, for example `this payment is a payment`.

- **Constants:**
  - Proper names: `Alice`, `Bob`
  - Strings: `"Hello"`, `'World'`
  - Numbers: `42`, `3.14`
  - Dates: `2023-10-27`

## 7. Arithmetic and Comparisons
- **Math:** `+`, `-`, `*`, `/`, `( )`, integer division `//` and remainder `mod` (`S = B // 3 + B mod 3`). Contract code that keeps a fixed number of decimals uses this arithmetic. (For example, the Ethereum Virtual Machine, the EVM, keeps amounts in units of 1e18.)
- **Functions:** the arithmetic functions `ceiling`, `floor`, `round`, `truncate`, `integer`, `abs`, `sign` and `sqrt` each take one argument in brackets, as in `the result is the multiple * ceiling(the amount / the multiple)`. Prolog calculates them with `is/2` while the query runs.
- **Constants and functions as operands:** the name of a constant (§2.2) and a function written without its last place (§2.3) can be operands, as in `the total is the price of a cup with capacity 200 ml + the fee`.
- **Comparison:** `=`, `>`, `<`, `>=`, `<=`, `==`, `!=` (`==` is `is equal to`, `!=` is `is different from`). A formula can be on **each side**: `N mod 3 = 2`, `2 = N mod 3`, `N mod 3 == 2` and `N mod 3 is equal to 2` all calculate `N mod 3` and compare the numbers. When one side has no value yet, `=` gives it the value of the other side, as in `R = N mod 3`. The system compares values that are not formulas (names, pieces of text, dates) exactly as they are written.
- **Variable names in expressions:** in an arithmetic expression, the system takes a word as a variable only when the word is an **id**. An id is one capital letter, or a short word in capital letters (refer to §6.1), as in `ENT = ETI * ATR - TO`. A descriptive word in lower case or mixed case, such as `amount` or `exposure`, is part of a *type* and not a variable name. Thus, in an expression, such a word does not refer to the same thing as a variable of the head of the rule. Use ids (for example `EXP`, `IAOR`, `A`) for variables in arithmetic.
- **System Templates:**
  - `*V1* is equal to *V2*`
  - `*V1* is greater than or equal to *V2*` (for numbers)
  - `*V1* is less than or equal to *V2*` (for numbers)
  - `*V1* is greater than *V2*` (for numbers)
  - `*V1* is less than *V2*` (for numbers)
  - `*V1* is after or equal to *V2*` (for dates)
  - `*V1* is before or equal to *V2*` (for dates)
  - `*V1* is after *V2*` (for dates)
  - `*V1* is before *V2*` (for dates)
  - `*V1* is *V2* days after *V3*` (for dates and numbers)
  - `*V1* is *V2* months after *V3*` (calendar months, for dates). When V3 and
    V2 are known, the system calculates V1. If the later month has the same day of
    the month, the system keeps that day. Otherwise, it uses the last day of the
    month (31 August plus 6 months is 28 February). When the two dates are known,
    the system calculates V2 as the number of FULL months between them (28 February
    is 6 months after 28 August, but 27 February is only 5 months after it). Write a
    deadline as
    `a limit is 6 months after the date and the other date is before or equal to the limit`.
    Do not write it as "183 days": six months after 28 August is 184 days later.
  - `*V1* is known`
  - `*V1* is the case` (V1 is a sentence). This template proves the sentence that a
    variable holds: `the sentence is the case`. `lib/deontic.le` uses this template
    to check the content of an obligation.
  - `*V1* is in *V2*` (V1 is one of the members of the list V2)
  - `the minimum of *V1* and *V2* is *V3*` (for numbers)
  - `the maximum of *V1* and *V2* is *V3*` (for numbers)
- **There are no `min`/`max` FUNCTIONS.** "The least of the limit and the repair
  cost" is a condition, not an expression. Write
  `and the minimum of L and R is P`. Do not write `and P = min(L, R)`. The system
  reads the second form without an error message. But the query then fails with the
  message "min(A,B)/0 is not a function". The same is true for `max`.

### 7.1 Date Handling and Comparisons
Logical English uses a date as a value of its own kind, the same as a number or a name:
- **Representation:** the system identifies a date when it reads the document. Internally, it keeps the date as a term of the form `date(Year, Month, Day)`, for example `date(2021, 10, 9)`.
- **Type System:** `date` is an ordinary type. When a template declares a variable such as `*a date*`, the system itself adds the type `date` to the ontology (??? to be confirmed).
- **Comparisons:** built-in templates compare two dates by their sequence in time:
  - `*V1* is after *V2*` (maps to `le_gt`)
  - `*V1* is before *V2*` (maps to `le_lt`)
  - `*V1* is after or equal to *V2*` (maps to `le_ge`)
  - `*V1* is before or equal to *V2*` (maps to `le_le`)
  Each of these templates becomes one of the standard comparison operators of Prolog (`@>`, `@<`, `@>=`, `@=<`). These operators compare `date(Y, M, D)` terms in the correct sequence of time.

## 8. Taxonomy (Ontology)
- **Is-a hierarchy:** `<Subtype> is a <Supertype>` or `<Subtype> is an <Supertype>`
- **Example:** `a student is a person.`

## 9. Ignorable Words
When the system compares a sentence with a template, it ignores some filler words. Thus you can write the sentence in a natural way:
- `a`, `an`, `the`
- `is`, `are`, `was`, `were`
- `has`, `have`, `had`
- `do`, `does`, `did`, `been`

## 10. Comments
- **Line Comments:** `%` or `#`
- **Block Comments:** `/* ... */`

## 11. Meta-Templates
A template can take a full sentence as one of its arguments.
- **Keywords:** `says`, `that`
- **Example:** `*the act* says that *the person* is liable.`
- **It is the case that:** starts the consequence of a universal quantification, or puts a statement inside it.

## 12. Testing and Expectations
A scenario can state the answers that a query must give. The test runner then checks these answers.
- **Syntax:** `<QueryName> expects answers ["Answer 1", "Answer 2"] and unknowns ["Unknown 1"].` (The `and unknowns [...]` part is optional. The word `answers` is also optional.)
- **The answers, with all unknowns:** `<QueryName> expects answers ["Answer 1"] and any unknowns.`
  Without an `and unknowns [...]` part, an expectation also says that the
  answers do not depend on unknowns. With `and any unknowns`, the test checks only
  the answers. An answer that depends on unknowns passes, whichever unknowns they
  are. Use this form when you expect a change in what an answer depends on, but no
  change in the answer. An example is a program whose conditions are not all
  translated into rules yet.
- The expectation names the query directly. Do **not** put
  `query` before it. (The system reports a section keyword at the start as a
  misplaced expectation.)
- **Flip queries** (§17.7) state their expected minimal change sets: `<QueryName> expects changes [["add: <fact>"], ["remove: <fact>", "add: <fact>"]].`
- **When they run:** the test runner (`runTests`, `runTestsFor/2`) runs all
  expectations. Verification occurs each time that the editor loads a program.
  Verification also runs the expectations, in a limited time (the Prolog setting
  `le_verify_tests_seconds`, 5 seconds by default). When the time ends, the system
  stops the test that is running. The system reports the tests that did not run,
  and the test that it stopped, one time, as a `tests_not_run` warning. Thus a
  program with many scenarios, or with one slow test, still opens quickly. The test
  runner runs all tests in full.
- **Numbers with decimals.** When an expected number has decimals, an answer passes
  if its number rounds to the expected number at that number of decimals:
  `["the minimum monthly repayment is 2398.20"]` passes when the answer is
  2398.2021006110276. A tester writes an amount to the cent, as the test cases of
  other rule systems do. (Oracle Intelligent Advisor compares a currency as it shows
  it.) The arithmetic of the system keeps all digits. The system compares the exact
  text first. It still compares a whole number (`2398`) exactly.
- **Example:**
  ```le
  scenario alice is:
      John is born in the UK on 2021-10-09.
      one expects answers ["John acquires British citizenship on 2021-10-09"] and unknowns ["John is a good person"].
      two expects ["John is a British citizen"].
      three expects ["John acquires British citizenship on 2021-10-09"] and any unknowns.
  ```

## 13. System Predicates
Logical English gives several built-in predicates. These are named relations that the system itself defines. A program uses them through the `prolog` keyword (§15.6). With these predicates, a program can also ask questions about itself.

- **`le_my_kb(KB)`**: gives `KB` the name of the knowledge base that runs.
- **`le_my_id(ID)`**: gives `ID` the identifier of the rule or fact that the system uses.
- **`le_type(Type)`**: true when `Type` is a type that the ontology or the templates define.
- **`is_a(Subtype, Supertype)`**: true when `Subtype` is below `Supertype` in the taxonomy.
- **`le_source_element(RuleID, Designator, Goal)`**: tells which condition of a numbered rule each designator (such as `1.1.a`) refers to.
- **`le_source_section(SectionName, RuleID)`**: tells the section of each rule (refer to §3.1). A rule with no section marker above it is in `main`.
- **`le_source_info(Ref, Start, End, ID)`**: gives the location in the source file (the first and the last character), and the identifier of the rule or fact.
- **`le_issue(Severity, Type, Description, Fix, Start, End)`**: one problem that the system found when it read or checked the program. The problem is an error or a warning.
- **`le_dict(dict(FunctorArgs, NamedTypes, WordsAndVars))`**: holds a template in the internal form of the system.
- **`le_kb(Name)`**: holds the name that the source gives to the knowledge base.
- **`scenario(Name, Facts)`**: holds the facts of a named scenario.
- **`query_info(Name, Goal, Items)`**: holds the data that the system has about a named query.
- **`le_expected(QueryName, ScenarioName, ExpectedAnswers)`**: holds the answers that a query must give in a scenario.
- **`ontology(Content)`**: holds the ontology section exactly as you wrote it.

## 14. Included Resources
A Logical English program can include other LE programs. To do this, write an `includes these resources:` header.
- **Syntax:**
  ```le
  the knowledge base myKB includes these resources:
      Resource1, Resource2.
  ```
- **Resources:** a resource is a file path relative to the program (for example `royal_family`), or a web address (`https://le2.logicalcontracts.com/source/royal_family`). It is not necessary to write `.le` at the end.
- **Behavior:** the system adds the included rules, facts, templates and ontology to the knowledge base that includes them. It uses them when it answers a query. It ignores the scenarios and the queries of an included resource.
- **Transitivity:** an included resource can include other resources. There is a limit on the length of the chain (the Prolog setting `le_include_max_depth`, 5 by default). When a resource is included two times, or when there is a circle of includes, the system finds the problem and skips the resource. The system finds the path of each resource **relative to the file that includes it**. That is, the path is relative to the folder of that file, or to its folder on the web.
- **Local-path restriction:** a resource can be a file on the same computer. You can include such a file only when it is below the folder of the file that includes it, or when it is a file that all users can read on the server, as `restricted_paths` permits. This restriction does not apply to a resource at an `http(s)` address on a different computer.
- **Source positions:** each included `.le` resource has its own range of character positions. The system moves the positions of the characters of the resource into that range (a multiple of `le_grammar:resource_offset_unit/1`, one range for each resource, `le_kbs:resource_base/2`). Thus the system never confuses the records for a resource with the document that includes it. Such records are where a rule starts and ends, the identifier of a rule, a condition, a problem, and a note of the origin of a fact. Each reply of the `/leapi` address of the server marks a range in a resource with `resource`, `resourceExample`, `resourceLine`, `resourceStart` and `resourceEnd` (`le_kbs:annotate_resource_ranges/2`). The editor then opens the resource at that line in a new tab. It does not select text in the document on the screen. This occurs for a step of an explanation, for a node of the graph, and for *Show definition*. The editor shows the problems of a resource on the `includes these resources:` section. A printed message gives the file and the line, `(apparel.le, line 53)`.

### 14.1 Prolog resources (`.pl`)
A resource whose name ends with `.pl` (a file or a web address) is a **Prolog resource**. Such a resource gives an LE knowledge base a file of Prolog facts and predicates, for example a large lookup table. The LE program uses that file through a *thin layer*. The layer is a small number of templates, and rules whose conditions are `prolog` goals (§15.6). The main program includes the layer, and the layer includes the `.pl` file:
```le
% layer.le
the knowledge base layer includes these resources:
    postcodes_facts.pl.
the templates are:
    *a postcode* is in *a region*.
the knowledge base layer includes:
    a postcode is in a region if
        prolog postcode_region(the postcode, the region).
```
- **The system only stores the clauses of the file. It never runs the file** (it never uses `consult`). It stores the clauses in a separate module, with a name from the content of the file. A reasoning session then imports that module. During the load, the system obeys only three directives: `dynamic/1`, `discontiguous/1` and `use_module(library(...))`. It removes a `:- module(...)` directive, with a warning, and it loads the clauses that follow. It skips all other directives, with a warning. Thus a `.pl` file from a different location cannot run code only because a program includes it.
- **Safety while a query runs:** `library(sandbox)` checks each goal of a `prolog` condition before the goal runs. The check lets the predicates of LE itself run, because they only read data and change nothing. An installation that trusts its programs can stop the check. To do this, set the Prolog setting `le_sandbox_prolog` to `false`.
- **One load:** the system loads a `.pl` file again when the time of the last change of the file is later. It gets a `.pl` file at a web address one time for each run of the server. Thus, when you edit the LE program, the system does not load a large file of facts again.
- Refer to `examples/moreExamples/language/includes/prolog_resources/` (postcodes: main → thin layer → facts `.pl`).

### 14.2 Shipped libraries (`lib/`)
A library is an ordinary LE resource in `lib/`. The system copies a library into the
folder of the program that includes it (`le_migration:copy_library/2` does the copy
for the translators). Thus a program and its libraries are in one directory.
- **`lib/temporal.le`** (+ `temporal.pl`): dates, periods and lock times.
  The library has
  `the age on *a date* of someone born on *a birth date* is *a number*`,
  full years / months / days between two dates,
  `*a later date* is *a number* years after *a date*`, `... calendar months after ...`,
  `*a date* is in the period from *a start date* to *an end date*`,
  `*a date* is within the last *a number* months before *a reference date*` (and
  `days`), the first and last day of a month, the year / month / weekday of a date,
  leap years, and Bitcoin lock times
  (`the lock time *a number* is a block height` / `is a time`,
  `block *a height* is at least *a number* blocks after block *a first height*`).
  The predicate of `temporal.pl` with the name of each template answers that
  template. Thus the library is part of core LE. In a program that includes the
  library, the verifier does not report the templates of the library as untested.
  Refer to `testing/fixtures/temporal/uses_temporal.le`.
- **`lib/text.le`** (+ `text.pl`): pieces of text.
  `the joining of *a list* is *a text*` (the items of the list one after the other,
  a number without a `.0` at the end, a date as 2026-10-15),
  `the text of *a value* is *a text*`, `the length of *a text* is *a number*`,
  `*a text* contains *a part*`, `*a text* ends with *a part*` (`starts with` is part
  of LE itself, §7). The rule systems that the translators read make messages and
  HTML in this way (in Oracle Intelligent Advisor: `"Feedback for " + the parent form`,
  `Contains(the screen, "&")`). Refer to
  `testing/fixtures/libraries/uses_text_maths_lists.le` (run by
  `testing/test_text_maths_lists_libs.pl`).
- **`lib/maths.le`** (+ `maths.pl`):
  `the power of *a number* to *an exponent* is *a result*`. The expressions of LE do
  not have a power operation (for example, the repayment of an annuity:
  `the power of 1.005 to -360`).
- **`lib/feel.le`** (+ `feel.pl`): the built-in functions of FEEL, the expression
  language of DMN, that the other libraries do not have. The DMN translator uses it
  (`integrations/dmn.md`). The library has a date written as text
  (`the date written as *a text* is *a date*`), a date from its parts, the day of the
  month, substrings and case, the functions of a list (count, sum, minimum, maximum,
  mean, median, product, the item at a position, a sublist, the distinct values,
  flattening, concatenation, union), the rounding modes of FEEL that
  `lib/rounding` does not have (away from zero, toward zero, half toward zero),
  `*a number* is odd`, `*a number* is even`, and FEEL's `all()` and `any()` with
  three values (`the conjunction of the list *a list* is *a truth value*`: no value
  when an item is not a truth). Each template that gives one value is a function
  (§2.3). Refer to `testing/fixtures/feel/uses_feel.le` (run by
  `testing/test_feel_lib.pl`).
- **`lib/lists.le`** (+ `lists.pl`):
  `*a list* is *an item* followed by *a second list*`. With this template, you can
  make a list one item at a time, in each direction (for example, the payments of a
  loan from the first to the last, each payment from the payment before it).
- **`lib/deontic.le`**: obligations, permissions and prohibitions (the
  deontic pattern library). The library has
  `*a party* is obliged / permitted / forbidden that *a sentence*`,
  `the obligation (prohibition) of *a party* that *a sentence* is violated`,
  `*a party* complies with the obligation that *a sentence*`,
  `*a party* is in breach`. A program concludes the deontic statements. The library
  says when a statement is violated: the sentence of an obligation is not the case,
  or the sentence of a prohibition is the case. The reparation of a program is a rule
  that concludes a new obligation from a violation:
  `a person is obliged that the person pays 200 penalty units if the prohibition of the person that the person engages in a credit activity is violated`.
  The library says nothing about time. It says who has an obligation, and what is
  violated, in one case. The translator for LegalRuleML (InsurLE2 Phase 2f) writes
  its programs with this library.

## 15. LE Extensions
This section is about features that are not in the core constructs above.
Three of these features are part of core LE, and this document describes them:
`only if` rules (§15.1), rule labels with their provenance (§15.5) and embedded
`prolog` goals (§15.6). The other constructs of this section are `which` relative
clauses (§15.2), `unless` in the conditions of a rule (§15.3), grouped alternatives
`either:` / `any of:` / `at least one of:` / `all of:` (§15.4), numbered rule
bodies (§15.5) and prepositional chaining (§15.7). These constructs need the
proprietary `le_extensions.pl` module. This module is installed where Logical
English is available as a hosted service. Without that module, these constructs
are not available. [LE Extensions](extensions.md) describes them, with the same
section numbers.

### 15.1 `only if` rules (necessary conditions)
`Head only if Body.` says that Body is a **necessary** condition for Head.
This is the rule read in the opposite direction. The system changes the sentence
into the rule *"opposite-of-Head if it is not the case that Body"*:
- When the template of the head declares an `; opposite:` form, the derived rule
  concludes that form. Thus the program can say directly
  `we will not pay X` when a condition for the payment fails.
- When there is no declared opposite, the conclusion is the plain negation of Head.
```le
the templates are:
    I will marry *a woman*; opposite I will not marry *a woman*.
    I love *a woman*.

I will marry a woman if the woman is "Alice".   % sufficient condition
I will marry a woman only if I love the woman.  % necessary condition:
                                                % I will not marry W if
                                                % it is not the case that I love W
```
An ordinary `if` rule gives a sufficient condition. An `only if` rule operates as a
constraint, and it makes negative conclusions. Refer to
`examples/moreExamples/language/negation/only_if.le`.

### 15.5 Rule labels and provenance
A rule can have a label: `rule <name>: Head if ...`. The label becomes the
identifier of the rule. `le_source_element/3` and `le_source_info/4` show this
identifier (§13). A label can also tell the origin of the rule. This is core LE,
and it needs no extension. The label names a document and, if possible, a location
in that document:
```le
rule note_61_4_pockets with provenance HTSUS Chapter 61,
        confer "Headings 6105 and 6106 do not cover garments with pockets below the waist":
a garment is excluded from heading a heading
    if heading the heading is a shirt heading
    and the garment has pockets below the waist.
```
Write `with provenance <document>`. The document is a name, or a quoted piece of
text such as a web address (`with provenance "https://example.org/act.html#s2"`).
After the document, you can write `at <locator>` (`at section 4`), or
`, confer "<passage>"`, a quotation of the document (§17.1).
The system also accepts here the trailers of a fact (`according to`,
`as stated in`, `because`). The system records the provenance as
`le_rule_provenance(ID, Prov)`. Prov has the same shape as for a fact. The
provenance changes nothing in the proof. Explanations and the editor show it
(§17.1, *Documents*). The header of a decision table accepts the same addition:
`the table apparel is, with first match, with provenance ...:`. The system records
it with the identifier of the table, `table_<name>`.

### 15.6 Embedded Prolog goals
A condition of the form `prolog <goal>` runs a goal that you write directly in
Prolog. Put two or more goals in brackets: `prolog (g1, g2)`. In the goal, write an
LE variable as a `the <name>` phrase, as a `*a name*` marker, or as an ALL-CAPS id.
The variable then gets the value that the goal finds for it. Such goals frequently
use the built-in predicates of §13. A program also uses a Prolog resource (§14.1) in
this way:
```le
an id has designator a d if
    prolog (le_my_kb(KB), KB:le_source_element(the id, the d, the g)).

a postcode is in a region if
    prolog postcode_region(the postcode, the region).
```
- **Safety:** `library(sandbox)` checks each `prolog` goal before the goal
  runs (§14.1). When the check rejects a goal, the query stops with an error.
- **Explanations** show the goal as a built-in step. The other target
  languages do not run such a goal. s(CASP) reports it as not supported
  ([scasp.md](scasp.md)).
- **Kept answers:** the verifier reports a memorable template (§2.4)
  whose rules use a `prolog` goal (`memorable_calls_prolog`). The reason is that a
  goal that changes something in a different location can make the kept answers
  out of date.

Refer to `examples/moreExamples/language/prolog/prolog_call.le`,
`language/includes/prolog_resources/` and `language/rules/rule_id_test.le`.

## 16. Humanizing LE
Lawyers and other domain experts read LE programs more frequently than they write
them. The guidelines below use the features above to keep a program similar to
ordinary text:

- **Use `only if` for necessary conditions.** Policy text says "we will pay
  only if the premium has been paid". Write exactly that. Also declare the
  natural `; opposite:` form. Then the derived negative conclusion has the words
  that the author of the text would use (`we will not pay ...`).
- **Use prepositional additions to make a chain in one sentence.** Declare
  `; prepositional` for relations that are similar to prepositional phrases. Then a
  condition can be
  `we will make a payment under this policy in respect of a claim`, and not three
  unnatural sentences that repeat the subject.
- **Use `which` to continue an idea.**
  `a parent of a child which is an ancestor of the descendant` does not need a
  second invented variable name that you must repeat.
- **Use `unless` for exceptions.** When the source text gives a condition as an
  exception, `unless the claim is fraudulent` is much easier to read than
  `and it is not the case that the claim is fraudulent`.
- **Use `either:` / `any of:` blocks** for lists of alternatives. Do not use
  `or` lines at many levels, mainly when the source text is itself a list.
- **Copy the structure of the source document**: name each rule with
  `rule <label>:` from the clause that it encodes. Use numbered bodies when the
  clause is a numbered list. Put rules into groups with `section ... is:` / the
  annexes header. Cite the clause in a `%` comment. When a reader can find the
  origin of each rule, the program is easier to read.
- **Declare `; synonym:` forms**. Then a fact, a line of a scenario and a query can
  each use the words that are most natural in their location. An explanation shows
  each sentence in the words that you wrote it in.
- **Keep the words of templates near to the source text**. Let the ignorable
  words (a/an/the/is/are...) give the grammar. Use several short templates, each
  with its parts clearly visible. Do not use one template as long as a full
  sentence, because such a template hides the logic in it.
- **Say how the program knows each statement**. Use `; assumable` for a matter of
  expert judgment, and `; undefined` for the data of a case. A reader then sees
  immediately which statements are evidence, which are decisions of a person, and
  which statements the rules calculate.
- **Give individuals names with a meaning**: descriptive constants without
  determiners (`claim one`, `wrist injury`, `United Kingdom`). These names occur
  exactly in answers and explanations.

## 17. Regulatory-decision constructs
This section is about the constructs for programs that apply written rules to
recorded cases. Such a program has the shape of a regulatory decision. Is the rule
applicable? What is the answer to the one contested question? What follows? Each
fact has a source, and a person decides the contested question.
The examples are in `examples/regulatory/`. `eu261_integration.le` uses all of
these constructs together, on the facts of the Wallentin-Hermann judgment of the
Court of Justice of the European Union. Two larger applications are also there.
`examples/regulatory/customs/` classifies goods under a tariff. It runs the General
Rules of Interpretation and the notes of Chapters 39, 61 and 62 on rulings of US
Customs and Border Protection and on EU binding tariff informations.
`examples/regulatory/medicare/` holds the 58 coverage policies for durable medical
equipment. It runs them on claims and on decisions of the Medicare Appeals Council.
The two applications are examples, given "as is", and they are not advice. The
first comment of each program says this in full.

### 17.1 Provenance trailers and judged templates
Each fact of a scenario, and each fact of the knowledge base, can have
**trailers**. Each trailer comes after a comma. You can write the trailers in any
sequence:

| Trailer | Meaning |
|---|---|
| `according to <source>` | who states the fact: a party, a witness, a document type, a service, a court. `<source>` is an ordinary constant. |
| `as stated in <document> at <locator>` | where the fact is written (`at <locator>` is optional). Without `according to`, the document is the source. |
| `because "<text>"` | the reason. |
| `confer "<passage>"` | a quotation of the passage of the document that states the fact. The document is the document of `as stated in`, or the default document of the scenario. |

```le
scenario decided is:
    claim one is for the burst pipe, as stated in the claim form at section 2.
    the burst pipe is accidental,
        according to the loss adjuster, as stated in report LA-17 at page 3,
        because "corrosion was not visible on inspection".
```
The trailers can start on the line of the fact, or on the next line. In the second
case, the line of the fact ends with the comma.

**The default provenance of a scenario.** Usually, a scenario takes all its facts
from one document. Then the header of the scenario names that document one time,
and each fact only refers to its own passage:
```le
scenario ny_n362700 is, as stated in ruling NY N362700:
    style 1025AD is an upper body garment,
        confer "is a men’s upper body garment constructed from 92 percent polyester".
    style 1025AD is napped.
    style 1000AD has pockets below the waist,
        according to CBP, confer "a portion of each of these pockets is below the waist".
    style 1025AD is shown in the catalogue, as stated in the importer's catalogue at page 3.
```
A fact with no trailers takes the default. A fact whose trailers name no
document (`confer`, `according to`, `because`) takes the default document. A
fact with its own `as stated in` names a different document. A comma that is *not*
followed by a trailer keyword stays part of the fact, as usual.

- **The trailers do not change the proof.** The system reads the fact exactly as it
  reads the fact without the trailers. It records the provenance with the fact
  (`le_fact_provenance/4`, recorded with the location of the fact in the source).
  Each session that loads the scenario receives
  `le_provenance(Fact, Source, Document, Locator, Rationale)`. A part that is not
  there is `none`. When there is no `according to`, the source is the document.
- **Explanations** show a proved fact with its trailers, as you wrote them:
  `the burst pipe is accidental, according to the loss adjuster, as stated in report LA-17 at page 3, because "..."`.
- **`scenario facts require provenance.`**: a statement about the full program.
  Write it after the target-language line. Then each scenario fact without a
  trailer causes a `fact_without_provenance` warning.
- **`; judged`** (a template addition, §2): a person decides the matter, and the
  rules do not calculate it. The system solves such a template as it solves
  `; assumable`, but with the rule about outcomes below. The effects are:
  - a rule that concludes a judged template is an **error**
    (`judged_with_rules`);
  - a judged fact in a scenario without `according to` or `because` causes a
    `judgment_without_provenance` warning;
  - a sentence that is still open (a sentence that the system assumed) shows in an
    explanation as `the burst pipe is accidental (judgment needed)`. The list of
    unknowns of the answer does not change (`"the burst pipe is accidental"`);
  - **the last argument is the outcome** when the template has two or more
    arguments, the same as for a service (§17.6). The template
    `the principal use of *a good* is *a use*; judged.` asks one question for each
    good. When a question has a recorded outcome
    (`the principal use of the bin is household use, according to CBP, ...`), the
    system assumes no other outcome for that question. A question with no record
    stays open, with one judgment needed for each outcome that the rules try. Thus
    write a judged template with its outcome last
    (`the claim that *a good* is *a kind* is *an outcome*`), and not as a plain
    relation between two things.

**Documents.** A document that a fact cites is an ordinary constant
(`ruling NY N362700`, `the benefit act`) or a quoted piece of text, such as a web
address. Two built-in templates tell where the document is:
```le
ruling NY N362700 is published at "https://rulings.cbp.gov/ruling/N362700".
the text of ruling NY N362700 is at "sources/cbp/N362700.txt".
```
The first fact gives the page that a reader opens. The second fact gives the plain
text of the document. That text is a file in the folder of the program, or a web
address. The system looks for the file only in the folder of the program, never
outside it. At a web address, the system reads the `text` field of a reply in JSON.
JSON is a usual format for data that programs send to other programs. When the reply
is a web page, the system reads the text of the page. The system does not read a
PDF. The two facts do not need their own provenance. With the two facts:
- the verifier checks a **quotation**
  (`confer "a zipper garage at the top of the collar"`) against the text of the
  document, when that text is a file in the folder of the program. (A locator in
  quotes, `at "section 4, paragraph a)"`, is a location, not a quotation. The
  verifier does not look for it.) The verifier ignores differences of white space,
  of no-break spaces and of letter case. It gives the warning `quote_not_found`
  when it cannot find the passage;
- each step of an explanation that a cited fact or a labelled rule proves has its
  provenance
  (`provenance: {source, document, locator, quote, rationale, url, text}`, and also
  `rule` for a rule). The editor marks the step with a **§** badge. The source viewer
  then shows the text of the document, with the quoted passage highlighted.
  *Open original* opens the published address. When that address has no anchor of
  its own, the editor adds a `#:~:text=` fragment. Then the browser goes to the
  quotation. The `documentText` operation of the server gives the text. A step also
  has a `plain` field: its sentence without the trailers. This field is for a screen
  that shows the citation separately. The executive view lists the cited steps of an
  answer in this way;
- in the program itself, the context menu of the editor has the item **Show original
  text** on each line that cites a document with an address. Such lines are a fact
  with provenance, the `with provenance` label of a rule or a table and the lines
  below it, a scenario "as stated in" a document (its header and its facts), and a
  `... is published at` or `the text of ... is at` statement. The editor opens the
  same source viewer, at the passage that the line quotes. When only the published
  address is known, that page opens. The reply that loads the program lists these
  lines (`citations`). The `provenanceAt` operation tells which document the line at
  the cursor cites. That is the innermost citation. Thus, for a fact that names its
  own document, the editor does not show the document of its scenario.

**The values that a place reads.** For each place of a scenario template, the
program itself tells which values are important: the values that its rules read in
that place. The system finds these values one step along the rules. They are the
facts of a relation that shares the variable, the members of a list that the rules
compare the variable with (`is in [...]`), the constants where the value goes into a
conclusion, and the column of a decision table. The fact forms of the editor, in the
Scenario Editor and in Scenario Variations, show these values in the field as
suggestions. The prompt that gets facts from a document also lists them.
The verifier gives the warning **`unread_value`** in this case: a scenario fact puts
in such a place a value that no rule, fact or table row of the program uses, and a
value that the rules read is similar to it. An example is
`the fabric construction of style A is knit`, where the rules read knitted, woven
and other values: "Did you mean knitted?". The verifier does not report a value that
is not similar to any of these values, such as a free description or a name.

Refer to `examples/regulatory/judged_damage.le`, and to the customs and Medicare
programs (`examples/regulatory/customs/`,
`examples/regulatory/medicare/`). In these programs, each rule, table and fact cites its passage.

### 17.2 `otherwise` cascades
A line of conditions that **starts** with `otherwise` starts a new alternative.
The word `otherwise` binds less strongly than `and` and `or`. Thus all the text
before it, in the same block, is the previous alternative.
```le
the discount rate for a customer is a rate
    if the customer is a member and the rate is 20
    otherwise the customer is a student and the rate is 10
    otherwise the rate is 0.
```
`A otherwise B` means `A`, or else `B`, but only when `A` fails. The system
changes the pair into `A or (it is not the case that A, and B)`. Thus the failure
of all earlier alternatives is the guard of each alternative, and exactly one of
the alternatives applies. Details:
- **The guard is the conditions of the earlier alternative.** Some conditions only
  set a result. An example is `and the rate is 20`, which gives a value to a variable
  that no other condition of the alternative uses. The system does not put such a
  condition in the guard. Thus the question "is the discount rate for ann 10?" does
  not pass the guard only because 10 is not 20. The system decides this from the
  words only. It takes a variable as a result each time that no other condition of
  the alternative uses the variable. This is also true when the rule gave that
  variable a value *before* the cascade. Thus, when an alternative ends with a test
  of such a variable (`… and the code is equal to "X"`), the guard of the next
  alternative does not have that test. Write the test with the constant first
  (`"X" is equal to the code`). Then the guard keeps the test.
- **Decide one case at a time.** The guard operates when the system fails to prove
  something. Thus its variables must have values before the system reaches the
  cascade. Find the individual first, for example in the rule that uses this rule:
  `if the customer is a customer and the discount rate for the customer is the rate`.
  Then let the cascade decide.
- **Layout.** Only a line that *starts* with the keyword is a cascade line.
  `the claim is otherwise covered` is an ordinary sentence. In a nested block (for
  example, below `it is not the case that`), the indentation sets the limits of a
  cascade, as for all other conditions. Examine a line such as
  `the customer is a member and the rate is 20`. When the full line matches only a
  general pattern (`... is a ...`, `... is ...`, or a comparison such as `... = ...`),
  and each part matches separately, the system splits the line at its `and`. This is
  true on each side of the general pattern that included the `and`. Thus a one-line
  alternative
  (`otherwise the guest has an unbirthday today and the percentage is 10`) has the
  same meaning as the same alternative on two lines.
- **Explanations** show a guard that failed as a negation that refers to the
  `otherwise` line: `it is not the case that cy is a member`.

Refer to `examples/regulatory/otherwise_table.le`.

### 17.3 Decision tables
A **decision table** writes one relation as a grid. It has a column for each
argument and a row for each case. A table is for the ONE template whose words give
the name of the table. The template says `under table <name>`, and the table says
`the table <name> is`:

```le
the templates are:
    the shipping cost for a weight of *a number* kg is *a cost* under table shipping.

the table shipping is, with first match:
    band | weight kg          | cost
    s    | <= 1               | 5
    m    | > 1 and <= 10      | 12
    l    | > 10               | 30
```

Read a row as a rule. The row `m` says *the shipping cost for a weight of a
weight kg is 12 if the weight > 1 and the weight <= 10*. The system also changes the
row into that rule. Thus a query, an explanation and the verifier all see ordinary
rules about `the shipping cost …`. The grid adds what rules cannot say in one
location: the sequence in which the system tries the rows, and what to do when more
than one row applies (the **hit policy**, below).

**Where you write a table.** You can write a table in each location where you can
write a rule. It can be a separate section, as above. It can be between the rules of
a knowledge base. It can also be between the facts of a scenario, with the same
indentation as the facts. The table
ends at the first line that is not a row, that is, the first line without a `|`.
The rules or facts after that line continue as before.

A table in a **scenario** is part of that scenario, exactly as its facts are. The
table answers only while that scenario is the case. It **replaces** a table with the
same name in a different location. Thus a case can bring its own rates, its own
price list, its own schedule:

```le
scenario year 2025 is:
    the income of ann is 20000.
    the table rates is, with first match:
        band | income   | rate
        low  | <= 10000 | 5
        high | > 10000  | 30
```

Only an **indented** table is part of a scenario, with the same indentation as its
facts. A table at the margin after a scenario is a separate section. It is the
table for the full program, as before.

A table of **one column** is the exception. There is no `|`. Thus the system cannot
identify its rows from ordinary sentences, and the rows continue to the next
section. Write such a table as a separate section.

**Ask the table.** `under table shipping` is part of the words of the template.
Thus a rule (or a query) that uses the table also writes these words:

```le
the shipping cost for a customer is a cost
    if the order of the customer weighs a number kg
    and the shipping cost for a weight of the number kg is the cost under table shipping.
```

**The header line.** Write `the table <name> is`, then these parts, in this sequence. Each part is optional:

| Written | Meaning |
|---|---|
| `loaded from <file>.csv` | the rows are in a CSV file, not in the section (*Rows in a file*, below). CSV means comma-separated values. |
| `, with first match` / `, with unique match` / `, with all matches` | the hit policy. The hit policy says what to do when more than one row applies. When you write no hit policy, the hit policy is `with unique match`. |
| `, with provenance <document>` | the document that this table encodes, exactly as for a labelled rule (§17.1). It is also the document of the passages of a `confer` column. |

Then write `:`. The provenance can give the passage that the full table changes into
rules, the same as the provenance of a rule:
`, with provenance <document>, confer "<passage>"`.

**Columns and arguments.** The columns are the arguments of the template, **in
sequence**. The table concludes the **last** column. The columns before it are the
data that the table receives. Two columns are not arguments:

- **A row name**, in one more column at the front. An explanation then cites
  the row with that name (`row m of table shipping`). Without such a column, an
  explanation cites the row with its number (`row 2`).
- **A citation column**, in any location (*Citing a passage per row*, below).

The system reports `table_arity_mismatch` when the other columns do not agree with
the arguments of the template.

**What a cell can say.** A cell of an **input** column says what that argument must be:

| Cell | Matches |
|---|---|
| a value: `silk`, `5`, `"Of silk"`, `2026-08-31` | that value. The system reads it exactly as it reads the same words in a scenario. |
| nothing, `-`, or `any` | all values: this column has no condition for this row |
| `silk or wool or cotton` | one of those values |
| `> 1 and <= 10` | a condition: `<`, `<=`, `>`, `>=`, `=`, `!=` (the system also accepts `=<` and `==`), joined by `and` / `or` |

A cell is a condition only when *each* part of it is a condition. Thus a value
whose own words include `and` or `or` is still that value
(`with acute and chronic bronchitis`).

A cell of the **last** column is the answer, not a test. Such a cell holds a
value, or several values joined by `or`. These values then answer one at a time.
The system reports `table_bad_output` for all other contents.

Sometimes the cell of an input in a row is a **condition**. Then that input must
have a value before the system uses the table. The reason is that the system can
check a condition against a value, but a condition cannot make a value. When the
system uses the table while such an input has no value, an error occurs while the
query runs. The message names that column.

**Hit policies.** The system tries the rows from the top.

| Policy | When more than one row applies | For |
|---|---|---|
| `with first match` | the first row answers, and the system does not try the other rows | bands and cascades, where the last rows are the general case |
| `with unique match` (the default) | an error when the query runs, which names the rows. The table said that the case had only one possible row, and this was not true. | tables whose rows must not apply at the same time |
| `with all matches` | each row that applies gives one answer | a relation, not a function: for example, a code list or a table of pairs |

`with unique match` gives an error only for a case that the query actually asked
the table about. Several rows can apply to an input that is still unknown.

**Rows in a file.** You can put a long table in a CSV file in the folder of the
program, or in a directory below that folder. The section then holds only the
header line and the column headings:

```le
the table postcode_region is loaded from postcodes.csv, with unique match:
    postcode | region
```

The system reads cells as above, with two differences that are important for data:

- **The output cell of a CSV row is always a value**, also when its text
  contains `or` or `and`. (`Duchenne or Becker muscular dystrophy` is one
  answer, not two.)
- **Codes keep their shape.** The system puts quotes around a cell of text again
  when it reads the cell. Thus `012` or `G71.01` stays that code, and does not
  become the number 12.

When the first row of the CSV file only repeats the column headings, the system
skips that row. The system keeps the rows in memory, and it reads them again when the
file changes. A table from a file has no citation column. The system reports
`table_csv_missing` when the file is not there. A table in a scenario can also come
from a file. Thus a case can bring its own data file.

**Citing a passage per row.** In a table that is written in the program, one
column can cite, row by row, the passage that each row encodes. An example is the
line of a statute for a band, or the line of a tariff for a subheading. The heading
of this column is `confer`, for passages of the document that the `with provenance`
of the table names. Or the heading is `as stated in <document>`, for passages of a
different document. Each cell is a quoted passage, or empty:

```le
the table woven is, with first match, with provenance HTSUS General Rules of Interpretation,
        confer "the classification of goods in the subheadings of a heading ...":
    row | heading | material | code      | as stated in HTSUS Chapter 62
    w93 | 6214    | silk     | "6214.10" | "Of silk or silk waste:6214.10"
```

The system removes the citation column before it matches the other columns with the
arguments of the template. Thus the citation column is not an argument. The passage
of each row becomes the provenance of that row, exactly as the passage of a fact does
(§17.1). The step of the explanation for the row has the provenance, and its
**§** badge opens the passage. *View Original Text* on the row also finds the
passage. The verifier checks the quotation against the text of the document
(`quote_not_found`).

**What the system makes from a table.** It writes one rule for the template,
`Head :- le_table(Name, Args)`, and one record for each row (`le_table/6`,
`le_table_row/6`). It records these with the name of the table, or with
`in_scenario(<scenario>, <name>)` for a table in a scenario. Thus one name can hold
different rows in different scenarios. The system connects the template to a table
one time, to the table that is written first. The system decides which table answers
while the query runs, from the scenario that the session has loaded. An explanation
cites the row that answered (`row m of table shipping`). For a table in the program,
that citation refers to the line of the row.

The system reports these problems when it loads the program:
`table_without_template` (no template says `under table <name>`),
`table_arity_mismatch`, `table_row_width` (a row with an incorrect number of
cells), `table_bad_cell`, `table_bad_output` and `table_csv_missing`.

Refer to `examples/regulatory/otherwise_table.le`, `loaded_table.le`
(+ `shipping.csv`) and `scenario_table.le` (a table for each scenario). For a table
in a worked program, refer to §16 of the [gentle
introduction](../tutorials/intro-to-le/intro-to-le.md#a-decision-table).

### 17.4 The decision skeleton: applicability, question, remedy
This needs no new keyword. The large shape of a decision is: *is the rule
applicable, what is the answer to the question, what follows*. You write this shape
with the ordinary section markers (§3.1) and three reserved names. Each language
has its own three names, in `i18n/keywords.csv`:
```le
section applicability is:
a person is in scope if the person is resident.
section question is:
a person is eligible for help if the person is in scope and the person is on a low income.
section remedy is:
the help for a person is an amount if the person is eligible for help and ...
```
The system answers a query as before. The three names add a way to read a
query that **fails**:
- **`the query fails at section *a section*`** (also `the query fails at *a section*`)
  is a built-in template. It is true when the first query of the program, with the
  name "the query", has no answer. It names the section where the query fails.
  The sequence of the checklist is applicability, question, remedy, and then the
  other named sections in the sequence of the program. The section where the query
  fails is the first section in this sequence that holds a rule for something that
  the attempt tried to prove and could not prove. `the query *a name* fails at section *a section*` does the
  same for a named query.
  ```le
  query stage is:
      the query fails at which section.
  ```
  For a person who is not resident, this query answers
  `the query fails at applicability`.
- **The explanation of a failure starts with the checklist**:
  `section checklist: applicability passed, question failed, remedy not reached`.
  This does not change a program that does not use the reserved names.

Refer to `examples/regulatory/sections_benefit.le`.

### 17.5 Source-scoped proof: `according to` in a rule
In the conditions of a rule, or of a query, `according to <scope>` limits the proof
of the conditions before it to the evidence of one source. With this construct, you
write the burden of proof:
```le
a tenant owes the late penalty
    if the rent of the tenant is overdue
    and the notice was delivered to the tenant
        according to the landlord.

the courier is admissible under the landlord.
```
`G according to S` is true only when the system can prove G from these data: the
rules and facts of the program, together with only the **scenario facts** whose
source is **admissible under S**. The source of a fact is the source that its
`according to` names. If there is no `according to`, the source is the document of
its `as stated in` (§17.1). A scenario fact with no provenance is never admissible
in a scoped proof. The facts of the knowledge base are always admissible, because
they are rules, not evidence.
- **Layout.** Write `according to <scope>` on a separate line, indented below one
  condition. Then it applies to that condition. Write it on a line after several
  conditions at the same level, and it applies to all of them, for example to the
  conditions of an `it is not the case that` block. You can also write it at the
  end of the line of the condition.
- **Admissibility** is the built-in template `*a source* is admissible under *a scope*`.
  Alone, it is true only when the source and the scope are the same. A program can
  add facts or rules to make it apply to more sources
  (`the maintenance log is admissible under the carrier.`).
- **The scope** is an ordinary value: a constant (`the landlord`), a variable
  that the rule started before, or a new variable. `according to a party` gives
  the party whose evidence proves the condition.
- **Presumptions** need no special syntax:
  `G if it is not the case that <not-G> according to <the other side>`.
- **Explanations** show `the notice was delivered to ann according to the landlord`.
  A scoped proof that fails lists the evidence that it could not use:
  `the notice was delivered to ann, according to ann, is not admissible under the landlord`.
- The s(CASP) engine does not have this construct.

Refer to `examples/regulatory/scoped_notice.le`.

### 17.6 Services and semantic predicates over text
Rules cannot decide some questions, because their arguments are free text: "is
this description a vehicle?". A program can declare **services**, and let these
services answer such templates:
```le
the knowledge base semantic match includes these services:
    matcher at https://models.example.org/match as a semantic matcher,
    classifier at llm:openai/gpt-oss-120b as a semantic matcher.

the templates are:
    the best match of *a text* among *a list* is *a category*; via service matcher.
```
- **Declaration**: write `the knowledge base <name> includes these services:`.
  Then write `<name> at <address> as a <kind>` for each service. Put commas between
  the services, and a full stop at the end. The name of a service is one word. An
  address has one of four forms:
  - With `http(s)://...`, the system sends the question to that address as JSON.
    The reply is `{"answers": [[arg, ...], ...], "rationale": "..."}`.
  - With `llm:<model>`, the system asks a large language model through
    `llm/llm_client.pl`. An example is `llm:openai/gpt-oss-120b` on Groq with
    `GROQ_API_KEY`. The system gives the model the template and the arguments that
    are known.
  - With `stub:matcher` or `stub:judge`, the system asks a substitute service for
    tests. This service always gives the same answer. The LE server has these
    services at `/test_services/<name>`.
  - With `sheet:<workbook>`, the system asks a spreadsheet in the folder of the
    program (*A spreadsheet as a service*, below).
- **`; via service <name>`** (a template addition): that service answers the
  questions about the template. The **last** argument can be unknown. Then the
  service gives its value. All other arguments must have a value when the system
  reaches the question. Otherwise, the query stops with an error. When all the
  arguments are known, the service answers yes or no.
- **Built-in semantic templates**. The first service of the program that is declared
  `as a semantic matcher` answers these templates:
  `*a text* is semantically similar to *a second text*`,
  `the best match of *a text* among *a list* is *an item*`,
  `*a text* satisfies the description *a description*`.
- **Ask one time, keep the answer.** The system sends each different request
  **one time in each session**. Two requests are different when one of these is
  different: the service; the template; the inputs, written in one standard form
  (regular spaces in text, sorted lists); the version of the service (its address,
  or the model); or the version of the request format. When the Prolog setting
  `le_service_cache_dir` names a directory, the system also keeps the answers in
  that directory. It records them with the request itself, not with the program.
  The system uses them again in later sessions and in other programs. It refuses an
  answer that it kept for a different model or a different version.
- **Attribution.** An answer goes into the proof with the service as its source. Its
  explanation is
  `the best match of ... is vehicle, according to service matcher, because "<the service's rationale>"`.
  A scoped proof (§17.5) accepts the answer only under
  `according to service matcher`, or under a scope that the service is admissible
  under.
- **A service that the system cannot reach**: when there is no kept answer from
  before, the question becomes an unknown. The query still gives answers, with that
  condition, and nothing breaks.
- **Write the answers as facts**:
  `le_services:service_materialise(Session, KB, Lines)` writes the answers that a
  session used as ordinary scenario facts
  (`the best match of "..." among [...] is vehicle, according to service matcher, as stated in cache at <hash>.`).
  A program that has those facts runs without the service and without the kept
  answers. Thus you can repeat a run with the same result.
- **A spreadsheet as a service.** A workbook (an Excel `.xlsx` or `.xlsm`
  file) in the folder of the program can answer a template without a
  translation. An example is the calculator of an authority. A section of the
  program, `the cells of service <name> are:`, says which cells answer each
  template. Each sentence of the section is an instance of a template that the
  service answers, with a cell reference in double quotes in each place. The system
  writes the values that a question gives for the first places into those cells.
  Then it calculates the workbook. The cell of the last place holds the answer:
  ```le
  the knowledge base vitamin d bmi includes these services:
      bmi at sheet:sources/bmi/adult_bmi.xlsx as a calculator.

  the templates are:
      the ICD10 code of the BMI of *a number* kg and *a number* cm is *a code*; via service bmi.

  the cells of service bmi are:
      the sheet is "BMI".
      the ICD10 code of the BMI of "B1" kg and "B2" cm is "B4".
  ```
  The section can have two other sentences:
  - `the sheet is "<name>"` names the sheet of the cells that do not name their own
    sheet. (Write a cell of a different sheet as in Excel, `"'Rates 2026'!B4"`.)
    Without this sentence, the cells are on the first sheet of the workbook.
  - `the cell "<cell>" is <value>.` gives a cell the same text or number for all
    questions.

  All other cells keep the value that is saved in the workbook. The phrases of the
  section are keywords of the language of the program (`as células do serviço bmi são:`,
  `a folha é`, `a célula`, in Portuguese). The explanation gives the workbook as the
  source
  (`according to service bmi, because "adult_bmi.xlsx computed B4 from B1 = 118, B2 = 170"`).
  The workbook must be in the folder of the program. A changed workbook is a new
  version. Thus the system does not use again an answer that it kept from the old
  version. To ask a spreadsheet, the server must have Node and the packages of the
  sheet engine (`npm ci` in `services/sheet`). When these are not there, and in the
  editions that run in the browser, the question becomes an unknown.

  The verifier reports these errors:
  - a sentence of the section that it cannot read (`cells_unknown_sentence`);
  - a sentence about a template that the service does not answer
    (`cells_not_backed`);
  - a place that is not a cell reference (`cells_not_a_cell`);
  - two sentences for one template (`cells_twice`);
  - a section for a service that is not a workbook (`cells_unknown_service`);
  - a template that a workbook answers but that has no sentence (`cells_missing`);
  - an address with a `#` (`sheet_address_port`, the form of an earlier version).

  The verifier gives a warning for a workbook that is not at the address
  (`sheet_no_workbook`). Refer to
  `examples/regulatory/medicare/vitamin_d_bmi.le` and
  [Spreadsheets](../integrations/spreadsheets.md#asking-a-workbook-instead).
- The verifier reports `service_undeclared` as an error in two cases: when
  `; via service X` names a service X that the program does not declare, and when a
  program uses a built-in semantic template but declares no semantic matcher.

Refer to `examples/regulatory/semantic_match.le` (a substitute service, with tests)
and `semantic_llm.le` (a classifier that uses a large language model). The second
program states no expected answers, because its answers depend on the model.

### 17.7 Flip queries: which minimal change flips the outcome
```le
query flip_rich is:
    which minimal change to the scenario makes it the case that
        rich gets help to pay rent.

query flip_bob is:
    which minimal change to the scenario makes it the case that
        it is not the case that bob gets help to pay rent.
```
The answers are the **smallest sets of changes** that get the result: the smallest
number of changes, and each set of that size that operates. After such a set of
changes, the goal is true directly, with no assumptions. For
`it is not the case that G`, G then has no proof. One change **adds** or
**removes** one fact of a scenario-element template, that is, of a template with
the mark `; undefined` or `; judged` (§17.1). In a program that marks no template,
a change can apply to each template that no rule concludes. A flip never changes
what the rules calculate.
- The system writes an answer as its changes: `add: rich is on a low income`.
  The word `and` joins several changes. When the goal is true already, the answer
  is `no change is needed`. The proof of the changed scenario explains the answer.
- An undecided instance of a judged template is a one-step change, the same as the
  other changes. This change is a judgment (`add: the burst pipe is accidental`).
- **Expectations**: `flip_bob expects changes [["remove: bob is on a low income"], ["remove: bob is on other benefits"]].`
  (The sequence is not important, in a set and between sets.)
- **How the search operates.** The explanation guides the search, and the system
  checks each answer that it proposes. The system examines only changes that come
  from what an attempt at the goal used. Such a change is a scenario-element sentence
  that the attempt asked for and did not find as a fact (the system can add it). Or
  it is a scenario fact that the attempt used (the system can remove it).
  Sometimes the sentence that the attempt asked for has an open place, and the
  scenario gives no answer for it. An example is
  *for all cases in which bob is a parent of an other dragon* when bob has no
  children. Then the system puts in the place each individual of the type of the
  place that the scenario names. (Thus the system examines
  `add: bob is a parent of alice`.) The system never invents a new individual. It
  never fills a place for a number, a date, a list or text. It ignores a sentence
  with more than two open places. It does not fill a sentence that the scenario
  answers already (a claim that names its item does not get a second item). It
  never examines all the facts that the program can state. A set of changes grows
  one change at a time. The system applies each set to a copy of the session, and it
  solves the goal again. The attempt of each set gives the next changes to examine.
  Thus a change that opens a new path brings the conditions of that path into the
  search. Two Prolog settings set the limits of the search:
  `le_flip_max_changes` (3 by default) and `le_flip_max_evaluations` (400).
- **Kept facts**: a request can name templates that the flip must not change (the
  `keep` field of `answeringQuery`, a list of template labels, and
  `the flip keeps …` in a view, §17.10). These are the facts that define the case.
  Thus no answer proposes to change them to a different item code or a different
  beneficiary.
- **Without a written query**: you can also ask a flip as your own query. The custom
  query field of the editor, and the `customQuery` of `answeringQuery`, accept the
  sentence, as they accept all query bodies. The conditions of the body are joined
  by `and`, `or` and `it is not the case that`. The **Flip…** button of the editor,
  next to **Query**, writes the sentence for you. The goal is the negation of the
  answer that you selected: it asks what makes that answer not true. When the query
  has no answer, the goal is the query itself. The author can edit the sentence
  before it runs. The goal can still have variables
  (`the heading of which good is 3924`).

Refer to `examples/regulatory/flip_housing.le`.

### 17.8 Factors and precedent: a pattern, not syntax
To decide an open-textured issue (an issue marked `; judged`) from earlier
decisions, no special construct is necessary. The method is the *result model* of
precedential constraint of Horty. `examples/regulatory/precedent.le` is a library
in plain LE. A program includes this library as a resource. Then the program gives
three things:
- **factors**, as rules that name them: `a damage has factor suddenness if the damage occurred suddenly.`
  The program also gives the direction of each factor: `suddenness favours accidental.` / `wear and tear disfavours accidental.`;
- **the case base**, as facts about each decided case, cited with trailers
  (§17.1): `kitchen flood has factor suddenness, as stated in decision D-1 at paragraph 4.`
  / `kitchen flood decided for accidental, according to the ombudsman, ... because "...".`;
- **the connection into the rules**, which is an `otherwise` cascade (§17.2) around
  the judged template:
  ```le
  a damage counts as accidental
      if the damage is forced for accidental by a case
      otherwise the damage is accidental
      and it is not the case that
          the damage is forced against accidental by a case.
  ```
A case that decided for an issue *forces* a new situation for that issue in this
condition. The new situation has at least the factors in favour of the decided
case, and at most the factors against of the decided case. A case that decided against forces in
the same way, in the opposite direction. When a decision is forced, the explanation
is the analogy itself: the cited decision, and each factor that the two cases share,
with its source. When no decision is forced, the judged template stays open, and the
system reports it as a judgment needed. To check that the case base does not
contradict itself, ask the template `*an issue* has an inconsistent case base` of
the library as a query. Refer to `examples/regulatory/precedent_pattern.le`.

### 17.9 Facts from a document
The *Write it in English…* dialog of the Scenario Editor can also get facts from a
document. Under *From a document*, give the name of the document. This name is the
constant that the new facts will cite. You can also give the address of the text of
the document: a web address or a file in the folder of the program. *Fetch
text* loads the text. Paste or fetch the text, then click *Generate*. This function
is not limited to a specific kind of document or program:
- each fact that the system writes is a sentence of one of the templates of the
  program, which include the templates of the resources that the program includes.
  Each fact cites the passage that states it:
  `<fact>, confer "<passage copied from the text>"`, under a scenario whose
  header names the document (or `as stated in <document>, confer "..."`);
- when the program marks its scenario templates with `; undefined` or
  `; judged`, the system offers only those templates. With each template, it gives
  the values that its rules read in each place
  (`the kind of *a good* is *a kind*    [*a kind*: coat, dress, jacket, ...]`, a
  maximum of 200 values). The model then writes the words of the rules, and not
  near-synonyms that no rule reads. When the program marks none of its templates,
  the system offers all templates;
- the system asks the model for little reasoning (`reasoning(minimal)`), and it
  lets the model give long replies (`max_tokens(16384)`). Thus the system does not
  cut a long document in the middle of a fact. In the reply, the system changes a
  `%` outside a quoted passage into the word `percent`, because in LE a `%` starts
  a comment. It moves a full stop before the trailer of a fact to after the trailer;
- the system writes a `; judged` template only when the text reports the decision of
  a person (`according to <who>`, `because "..."`). The system never writes a
  template that the rules conclude. The conclusions of the document are what the
  rules must calculate again. They are not facts to give to the program;
- the system checks each passage against the text. It gives the warning
  `quote_not_in_text` when the model wrote the passage in different words and did
  not copy it. Then the system checks the facts against the program, as it checks
  all *Write it in English* results;
- when you gave an address, the system also adds the facts that tell where the
  document is (§17.1, *Documents*). Thus the § badges of the new facts show their
  passages.
The editor keeps the provenance of each fact with its row. In the software, this
function is `nl_to_le:english_to_le/8` with the options `document(Name)` and
`base(Dir)`.

### 17.10 Views: how a screen shows a program
A **view** says how a screen that runs the program looks to the person who uses
it. It says which facts a case states, how the screen puts them into groups, which
query gives the result, and what the screen shows next to the result. A view is a
section of fixed sentences, in the program or in a resource that the program
includes. Nothing reasons with those sentences, the same as nothing reasons with
`scenario facts require provenance.`:
```le
the view claim desk is:
    the title is "Passenger claim desk".
    the case is a scenario, with the documents it is stated in.
    the facts about "the booking" are
        a passenger is booked on a flight,
        the distance of a flight is a number km.
    the judgments are
        an event is beyond the actual control of a carrier.
    every fact shows who states it.
    the result is the answer to query claim, headed by the amount, in euros.
    the result shows the stage it reaches.
    the result shows its citations.
    the answers to "which case decided for which issue" are listed as "Precedents".
    the result is compared with scenario bird_strike.
    the result can be flipped.
    the documents of the case are shown beside the facts.
```
The executive view (`/executive?program=<program>&view=<name>`) shows the view
with ready-made parts on the screen. When a program has views, the executive view
lists them. The facts, questions and results that a view names are **sentences of
the templates of the program**. You write them as you write the conditions of a
rule. The table below gives the sentences that a view can use. They are in the
category `view` of `i18n/keywords.csv`. Thus you write a view in the language of
the program:

| Sentence | What the screen shows |
|---|---|
| `the title is "<text>"` | the title of the screen |
| `the case is a scenario[, with the documents it is stated in]` | a list from which you select one of the scenarios of the program (or a new case); the documents that its facts cite |
| `the case is about <constant>` | the subject of the facts that the answers of an interview state |
| `the facts about "<title>" are <instance>, <instance>, …` | a group of fact rows that you can edit, each with its citation. The facts of the group that the case does not state: one click states each fact. |
| `the judgments are <instance>, …` | the `; judged` facts, separately |
| `the other facts can be added` / `… cannot be added` | whether the case can state facts of other templates |
| `every fact shows who states it` | the `according to` of each fact |
| `the result is the answer to query <name>[, headed by <the word>][, in <unit>]` | the answers of the query. The value of its `which <word>` is in large type. |
| `the result is whether <instance>` | a yes/no result, for the query that the view writes |
| `the result reads "<text>" when it holds` / `… when it does not` | the result in the words of the view |
| `the result shows its citations` | the cited steps of the proof. Each step opens its passage. |
| `the result shows its reasons` | the facts that the result depends on. For a result that FAILS: **why not**, that is, the conditions that it did not satisfy (below) |
| `the result shows the stage it reaches` | the checklist of the applicability / question / remedy sections (§17.4) |
| `the result asks what is missing` | the case facts that the failed proof looked for. One click states each fact. |
| `the facts are asked one at a time` | an interview: the questions of the view. The screen asks each question only while the answer can still depend on it. |
| `the question for <instance> is "<text>"` | the question for a fact (and its words in the reasons and the flip) |
| `the result can be flipped[, as "<text>"]` | the minimal changes that change the result (§17.7) |
| `the flip keeps <instance>, <instance>, …` | facts that the flip never adds, removes or changes. These facts define the case (the item and its code, a date of service). Thus no answer proposes a different one. |
| `the section <name> reads "<text>"` | the stage checklist and "fails at" in the words of the view (`the section remedy reads "Conditions of payment"`) |
| `the answers to "<query body>" are listed as "<title>"` | a table of the answers of a different query, with a column for each `which` |
| `the result is compared with scenario <name>` | the result of a different scenario, and where it fails |
| `the documents of the case are shown beside the facts` | the cited documents. The documents of the case are open, with their passages marked. |
| `the cases are listed with their results` | all scenarios, each with its result and its expectation, run one after the other ("running case i of N", and a button to stop) |
| `the case is flagged as "<label>" when "<query body>"` / `… when query <name> has an answer` | a banner above all other parts each time that the query has an answer for the case (a refusal, a referral: a decision that stops the process). Use the second form for a query with text values, because a quoted query body cannot hold text values. |
| `the numbers are shown with <N> decimals` | the numbers of the screen, with N decimals. Without this sentence, the screen removes only the noise of floating point: it shows 698.4000000000001 as 698.4. |
| `the draft reads "<text with {the result}, {the answer}, {the answers}, {the facts}, {the citations}, {the reasons}, {the missing}, {the case}>"` | a text, filled from the result, that you can copy |
| `the draft reads "<text>" when it holds` / `… when it does not` | a text for each outcome: an approval and a refusal |

- **The verifier checks the view.** These are errors:
  - a sentence that matches no view form (`view_unknown_sentence`);
  - a sentence of no template (`view_unknown_template`);
  - a query or a scenario that the program does not have
    (`view_unknown_query`, `view_unknown_scenario`);
  - a question for a table that is not a query (`view_bad_question`);
  - two views with one name (`view_duplicate_name`).

  These are warnings:
  - a judgment whose template does not have the mark `; judged` (`view_not_judged`);
  - a fact that the case can state but that the rules also conclude
    (`view_derived_fact`);
  - no result (`view_no_result`);
  - a sentence written two times (`view_said_twice`);
  - a heading that the query does not ask for (`view_headed_by_unknown`);
  - the stage checklist in a program without the reserved sections
    (`view_stage_without_sections`);
  - citations or documents in a program that cites nothing (`view_nothing_cited`);
  - a section that the program does not have (`view_unknown_section`);
  - a kept fact that the rules conclude (`view_keeps_derived`).
- **Why not.** When a result fails, the reasons panel lists the
  **conditions that the case did not satisfy** (`le_why_not.pl`; `answeringQuery`
  with `whyNot: true` replies `unmet`). The system reads them from the explanation of
  the failure, one rule for each attempt. Sometimes several rules can conclude
  something. Then the system follows only the attempts that came CLOSEST. These are
  the attempts in which the most conditions were true before the condition that
  failed. From those attempts, it takes the attempts that satisfied the largest part
  of themselves. Thus the system never gives as a reason the first test of a
  different alternative (for example, the list of codes of a different policy).
  Each condition at the end of the list is one of two kinds:
  - `not stated`: a fact that the case can state but does not state. The record
    says nothing about it.
  - `not met`: a comparison that is false for the values of the case, a negation
    whose subject is true, a fact that the case states with a different value, a
    judgment recorded in the opposite direction, or something that no rule concludes.

  The screen shows each condition with the rule that asks for it, the provenance of
  that rule, and the facts that the rule compared. The citations of a failed result
  are the passages of those rules. `openQuestions` asks only for the facts that the
  closest attempts do not have. A draft names them as `{the reasons}` (all of them)
  and `{the missing}` (the facts to ask for). A list placeholder on a separate line
  gives one item on each line. `\n` in a draft starts a new line.
- **Edit the case.** When you change a fact, the results become out of date, and a
  **Re-evaluate** button comes on. When you push Enter in a field, the same occurs.
  An *automatically* box evaluates again after each change. After the new
  evaluation, the editor highlights the answers that changed, and it puts a line
  through the answers that are not there now. The rules cannot read some values in
  their location: a number in quotation marks where the rules compare it with a
  number, text written as a number, or a value that is nearly the same as a value
  that the rules read. The editor reports such a value above the result
  (`answeringQuery` replies `valueWarnings` for a case that you typed;
  le_verifier:fact_value_warnings/3. The same check on the scenarios of a program
  gives the `mistyped_value` warning). A fact that gives only a type
  (`vehicle 1 is a vehicle`) stays in the case, but the screen shows it on one line,
  not as a separate row. Each part of the screen tells what it is when you put the
  mouse pointer on it.
- **When the editor loads a program**, the reply has each view, ready to use
  (`views`, le_views:program_views/2). The `answeringQuery` operation adds the
  section `checklist`, and `unmet` with it. `openQuestions` gives the facts that a
  failed proof looked for. `draftView` makes a draft of a view.
- **The automatic view.** When a program declares no view of its own, the executive
  view offers one view (`view=*`). This view is the draft that the next item
  describes. The system calculates it only when you open the view (the operation
  `automaticView`, le_views:automatic_view/3). A view that the program declares
  replaces it.
- ***Generate LE view*** of the LE Assistant adds a first view, made from the
  program itself: its case facts as one group, its judged templates, its first
  query (or its first conclusion) as the result, and all other things that the
  program can show. The assistant then proposes a request to make that view better.

A tutorial that makes a view step by step: [IntroducingLEViews.md](../tutorials/views.md).
Refer to the views of `examples/regulatory/eu261_integration.le` (a claims desk),
`flip_housing.le` (an interview), `judged_damage.le`, `sections_benefit.le`
(its view *rent decision*: sections in its own words, why not, a flip that
keeps a fact, a letter for each outcome),
`examples/regulatory/customs/cbp_62.le` (a classification worksheet), and the
coverage desks of `examples/regulatory/medicare/pap_cases.le` and `pmd_cases.le`.

### 17.11 Case searches: every case, and properties
```le
query support cases is:
    which cases make it the case that
        a person gets rent support.

query both eligible and excluded is:
    is there a case in which
        a person is eligible for rent support
        and the person is excluded from rent support.
```
A **case** is what a scenario must say to make a goal true. It lists the facts that
the scenario states, the facts that the scenario must not state, and the values
that those facts must have. A scenario tests one case. A case search examines all
the cases that a program permits, without a scenario.

- **`which cases make it the case that G`** lists each case in which G is true.
  Each answer is one case, in general terms: *case 1 of 1: a person is a
  resident and the person has an income of an amount and the amount is less
  than or equal to 15000 and it is not the case that the person receives other
  benefits and it is not the case that the person is a student*. Each answer
  also names the scenarios of the program that satisfy the case, or says that no
  scenario covers it. A case that no scenario covers is a case that the tests of
  the program never tried. To list the cases in which G fails, ask about
  `it is not the case that G`.
- **`is there a case in which G`** looks for a case that breaks a property.
  Write G as the situation that must never occur:
  *a person is eligible for rent support and the person is excluded from rent support*.
  Each answer is a case in which the situation occurs. When there is no such case,
  the one answer says so. It also says if the search examined all cases
  (*there is no such case: the search covered every case*), or if it stopped at one
  of its limits. A scenario can expect that answer
  (`… expects answers ["there is no such case: the search covered every case"]`).
  Then the property is one of the tests of the program.
- **In the editor.** **Misc → Find Cases** asks either search about the selected
  query. The editor shows the sentence of the query in a dialog, where you can edit it.
- **A ready-made scenario.** Each case comes with a scenario that satisfies it.
  The search selects the individuals and the values: `person_1`, an income of
  17500 between the limits 15000 and 20000, a date that agrees with the date
  comparisons. In the editor, a case that no scenario covers has the button
  **Add as scenario**. The button adds that scenario to the program, with
  the name `case_2` (or the next free name). Run the query again, and the
  case shows *covered by scenario case_2*.
- **Which facts a case can state.** A case states facts of the
  scenario-element templates, as a flip does (§17.7). These are the templates with
  the mark `; undefined` or `; judged`. In a program that marks no template, these
  are the templates that no rule concludes. When the program itself states the facts
  of a template (for example, a table of rates), the search reads that template from
  those facts and never assumes it. The search can also assume a template with the
  mark `; unknown` (§3.3). The integrity constraints of the program
  (`it must not be true that …`, §3.3) remove the cases that they prohibit.
- **How the search operates.** The search is the reasoning of Logical English
  itself, run on an empty scenario. Each time that the reasoning needs a fact of a
  scenario-element template, it assumes the fact. Sometimes it needs a fact to
  be absent (`it is not the case that …`). Then it records each way in which the fact
  can be true. When the case is complete, it makes sure that none of these ways is
  true. An assumed fact that the case does not state is simply absent. A comparison
  that can make the fact true is replaced by its opposite
  (*the amount is less than or equal to 15000*). A comparison on a number that is not
  known yet becomes a constraint on that number. A constraint solver (the
  `library(clpq)` of SWI-Prolog) keeps the constraints. It removes the cases whose
  constraints contradict each other, and it gives each number its limits. The search
  solves date comparisons in the same way, in days. Two facts of a template whose
  last place holds a value (*a person has an income of an amount*), or of a
  template with the mark `; one value` (§2), are read as one fact: a person has one
  income. When a smaller case already gives a case, the search does not list that
  case.
- **Totals and lists of assumed facts.** A count of facts that the case assumes is
  read as *at least* the number of facts that the case shows. A note says this.
  A list of these facts is the facts that the case shows. A total is the sum of the
  values that the case shows, which include the values that are not known yet. The
  search keeps the total as a constraint.
- **What the search does not do exactly**: each answer tells this in a note.
  It can be a total or count (`is the sum of each …`) or a `for all cases in which`
  on assumed facts (above), a condition that the search could not solve and kept
  without change, or a limit that the search reached. Four Prolog settings set the
  limits: `le_cases_max` (200 cases), `le_cases_seconds` (60 seconds),
  `le_cases_max_negation_proofs` (40 ways to prove the goal of one
  `it is not the case that`) and `le_cases_max_denials` (64). "Every case" means
  each combination of the facts that the templates of the program permit, in
  those limits.
- **Without a written query**: as with all query bodies, you can also type a case
  search in the custom query field of the editor.

Refer to `examples/regulatory/case_search.le`, and to the query `rn cases` of
`examples/regulatory/medicare/aeds_cases.le` (41 cases of the Medicare coverage
of external defibrillators. The test claims of the program cover nine of these
cases).
