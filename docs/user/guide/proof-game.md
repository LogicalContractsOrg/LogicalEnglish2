# The Proof Game — A Teacher's Guide

*Kind: guide · Audience: teachers · Status: current (2026-09-20)*

The **Proof Game** changes a Logical English query into a puzzle that students do
with their hands. A query is a question to the program. In the game, students do not
read a proof. They *build* a proof. They move rules and facts together until they
have explained **why** an answer is true, or why something is **not** true. The game
makes the central ideas of logical reasoning visible, and students can move them on
the screen. These ideas are rules, facts, variables, matching, negation, and "for
all".

This guide explains the main ideas. It also tells you how to teach a lesson with the
game. You do not need to know about programming to read this guide.

---

## 1. What the game is for

To answer a query, Logical English **connects rules and facts together** into a
proof. In the Proof Game, a student builds that chain again with the hand:

- The **query** (the question) is at the top.
- Below the query are the **rules** and **facts** of the knowledge base, as cards
  that you can move. (The knowledge base is the set of rules and facts of the
  program.)
- The student **connects** the cards so that each condition of each rule is
  satisfied, down to plain facts.

When all the parts of the structure connect correctly, the proof is **complete**.
The game then shows colours and plays a sound. When two connected cards contradict
each other, the game shows a **clash**. The two results come immediately. Thus
students learn when they try different things.

The game operates for each query in each `.le` knowledge base. The examples in this
guide use `examples/moreExamples/happy_dragon.le`.

---

## 2. Launching the game

Do these steps:

1. Open a knowledge base in the **editor**.
2. Click **Load**.
3. In its list, select a **scenario**. A scenario is the set of facts for the
   reasoning.
4. In its list, select a **query**.
5. Click the **Proof Game** button.

The game opens in a new window.

> You can also play a query that has **no** answer in the selected scenario. The game
> then builds the proof that the query **fails** (refer to §6.1).

---

## 3. The board and the pieces

| Piece | What it is | How it behaves |
|-------|-----------|----------------|
| **Query card** (top) | The question to answer, for example *"which dragon is happy"* | Has one socket below it. The socket waits for the rule or fact that answers the question. |
| **Rule card** | A rule from the knowledge base: a **head** at the top, and below it one **condition** box for each condition of the body | Its head connects **upward** into the thing that it helps to prove. Each condition has a socket that you must fill. |
| **Fact card** | A plain fact from the scenario or the knowledge base | Connects upward to satisfy a condition. Facts have no conditions. A branch of the proof ends at a fact. |
| **Assumption card** (dashed amber border) | An **assumable** statement: a template that has the declaration `; assumable`, or a line *"it is unknown whether …"* in a scenario | Operates as a fact, but nothing *proves* it. When you connect the card, you **assume** that the statement is true. The game uses assumption cards for **abduction**. Abduction explains something that you saw: you assume a cause that explains it. For example, *"the grass is wet"* because we assume that *"it rained"*. |
| **FAIL card** (a red stop sign) | "This is not true" | Satisfies a **negation**, that is, a condition *"it is not the case that …"*. In a game for a query that has no answer (§6.1), it also says that nothing could prove a goal. |

(A template is the pattern of a sentence, with slots for the values.)

**Connections** are arrows. To make an arrow, move the mouse from the **output** of
a card (its top) to a **condition socket** (the bottom of a condition box). An arrow
means *"this card gives that condition."*

### Colours and feedback

- Each **predicate** has its own colour. A predicate is a kind of statement that the
  program can make, for example *is a dragon* or *is happy*. The **Predicates
  Legend** gives the list of the colours. With the colours, students can find the
  cards that can connect.
- **Green** = part of a complete proof.
- **Red (clash)** = two connected cards are not in agreement about the person or
  thing that they talk about. (A variable cannot be two things at the same time.)
- **Dark red (failing)** = a card that shows that something **fails** (refer to §6).

---

## 4. The central idea: matching and bindings

Most rules talk about *some* person, dragon, or thing with a **variable**. A variable
shows as a phrase such as *"a creature"* or *"a dragon"*. A fact talks about a
**specific** person or thing, for example *"alice"*.

When you connect a fact to a condition, the game **binds** the variable to the value
of the fact. The text on the cards changes and shows the value. For example, connect
*"alice is a dragon"* to the condition *"a creature is a dragon"* of a rule. Then that
creature becomes **alice** everywhere in the rule.

- Sometimes two connections try to bind the same variable to **different** values.
  Then you get a **clash**, in red. A clash shows unification. Unification is the
  matching of variables to values. Each proof depends on unification.
- A branch of the proof is complete when it ends in **facts**. Facts are things that
  are true in the scenario.
- The game **calculates** some conditions, and does **not prove** them. These
  conditions are arithmetic (*"the amount is the rent / 2"*), comparisons (*"the
  rent =< 1000"*) and date calculations. No card gives these conditions, thus their
  boxes have no socket. The game calculates them immediately when the connected
  cards give their inputs. For example, connect *"the rent of ann is 800"*. The head
  of the rule then becomes *"the help for ann is 400"*.
- If the result of the calculation is false, the connection clashes. An example is a
  rent of 1200 under *"the rent =< 1000"*.
- A condition with alternatives keeps its socket, for the alternative that a card
  proves. An example is *"N >= 3 or N = 2 and the patient is flagged"*. When the
  calculated alternative is true (a class of 3), you do not have to connect a card.

**Teaching point:** a proof is not one step. A proof is a *tree*. The query is at the
root, the rules are in the middle, and the facts are at the leaves. The student must
make the tree larger until each leaf is a fact.

---

## 5. "For all cases" conditions

Some rules use a "forall" claim: *"for all cases in which … it is the case that …"*.
On a rule card, this condition shows **two sockets**:

- one socket for the **case** ("for all cases in which *a creature is a parent of a
  dragon*"), and
- one socket for the **consequence** ("it is the case that *the other creature is
  healthy*").

To satisfy the condition, the student gives a card for the case, for example the
fact *alice is a parent of bob*. The student also gives a card that proves the
consequence, for example the rule that makes *bob* healthy. The two cards show, in
the simplest way, that the claim is true for this case.

---

## 6. Negation and "failure mode" — proving that something is **not** true

Negation is the most powerful teaching idea of the game.

A rule can contain a condition such as *"it is not the case that the creature
smokes"*. To satisfy that condition, the student must show that each attempt to prove
that the creature smokes **fails**. There are two ways to do this:

1. **The quick way: a FAIL card.** Move a **FAIL** card, the red stop sign, onto the
   negation socket. The FAIL card says "this is not true", and the negation is
   satisfied. The quick way is good for younger students, or for a first attempt.

2. **The thorough way: build the failure.** Connect the **rule that can prove the
   statement** to the negation socket. The game shows that connection as a dashed
   arrow with the label **"not the case"**. The rule changes to **failing mode**, in
   dark red. The rule now explains *why* the statement fails. Then the student builds
   the failure below the rule, one condition at a time. The student continues until
   a condition cannot be satisfied: a FAIL card at the end of a branch.

**Worked failure (happy_dragon).** *bob smokes* is false. Why? First, no fact in the
scenario states that bob smokes. Second, the smoking rule needs a creature that is a
parent of bob, is a dragon, and smokes. The only parent of bob is **alice**, and alice
is a dragon. But **alice does not smoke**. The reason is that no fact states that she
smokes, and nobody is a parent of *alice*. The failure tree that the student builds
follows exactly that chain of reasoning:

```
it is not the case that bob smokes
  bob smokes                         (fails)
    a creature is a parent of bob    (there is one — alice — a choice point)
    alice smokes                     (fails)
      a creature is a parent of alice  (fails — there is none)
```

A failure can contain a proof. An example is
`examples/moreExamples/collections/logical-thinking-talk/heart_failure.le` (scenario
`high_creatinine`, query `withheld`). There, "the guideline recommends aldosterone
antagonists for Frank" fails. The reason is that its condition *"it is not the case
that Frank has a contraindication to aldosterone antagonists"* fails. That negation
fails because the contraindication **is true**. Thus, below that condition of the
failing card, you put the usual green proof of the contraindication of Frank. Each
negation changes the work to the opposite: a failure to build becomes a success to
build, and a success to build becomes a failure to build.

**Teaching point:** you prove "true" and "false" in different ways. A positive proof
needs **one** way to succeed. A negation needs **all** the ways to **fail**. In
failing mode, students see this difference themselves, and nobody has to tell them.

### 6.1 A query with no answer: playing the failure

The same idea applies to a **full query that has no answer**. Select such a scenario
and query, and open the game as usual. The toolbar then says *"No answer: build the
proof that this query FAILS"*. The **query card itself** is in failing mode, in dark
red. Below the query card, you build a failure, exactly as below a negation:

- a **FAIL** card at each place where nothing could prove a goal, and
- **one failing-mode card for each rule that the reasoner tried**. Below each of
  these cards, you build the condition that failed, in the same way.

The proof is complete when you show that each possible way to succeed fails. **Show
Proof** builds that answer key here, as in the other games.

A failed query in the game is the equivalent of *Why not* in the editor. *Why not*
gives a list of the conditions that a failed query did not satisfy. In the editor,
the student reads the reasons. In the game, the class builds the reasons.

**Worked example.** A claim is payable if three conditions and one more condition are
true. The claim is for an item with code "A1", the item was furnished to a person,
and that person is hypoxemic. A person is hypoxemic if the saturation of the person
is 88 or less. The record states the item and the person, but no saturation. The
query *"which claim is payable"* has no answer:

```
which claim is payable                 (fails)
  a claim is payable                   (the rule that tried; its first three
                                        conditions hold, the fourth does not)
    Ann is hypoxemic                   (fails)
      a person is hypoxemic            (the rule that tried)
        the saturation of Ann is a number   (FAIL — the record is silent)
```

**Teaching point:** a query that fails is not an error, and it is not a "no". It is a
conclusion that has its own proof. The proof tells exactly what is missing from the
case.

---

## 7. Choosing which answer to prove

A query such as *"which dragon is happy"* frequently has **more than one** answer. The
answers can have very different proofs. When there is more than one answer, an
**"Answer to prove"** list appears in the toolbar. Select the answer that you want the
class to work on.

Some answers are true only because something is **assumed** (refer to the Assumption
card). The list gives each such answer with its assumption. For example, in
`examples/moreExamples/language/abduction/grass_is_wet.le`, the list gives *"the grass
is wet, assuming it rained"* and *"the grass is wet, assuming the sprinkler was on"*.
These are two different **explanations** of the same observation. Each explanation
has its own proof to build.

For example, in `happy_dragon.le`:

- **"bob is happy"** is true *vacuously*. Bob is a parent of nobody, thus the "for all
  cases" condition has nothing to examine. This is a good first example.
- **"alice is happy"** needs the full failure argument about smoking from §6. This is
  a rich, advanced example.

When you change the answer, the same cards stay on the board. Only the target
changes.

---

## 8. Reusing a rule: the Clone Tool

Sometimes a proof needs the **same rule two times**. This occurs most frequently when
you build a failure tree. In the example above, the proof uses the smoking rule one
time for *bob* and again for *alice*. You can connect each card in only one place.
Thus you make a copy of the card.

- The **Clone Tool** button appears **only when the proof of the selected answer
  needs a copy**. Thus the button is not in your way until you need it.
- Click **Clone Tool** to make it active (it becomes highlighted). Then click a card
  to make a copy of it.
- To remove a copy, click the copy to select it, and push **Delete** (or
  **Backspace**). The game always keeps a minimum of one original of each card.

---

## 9. The toolbar at a glance

| Control | What it does |
|---------|--------------|
| **Answer to prove** | (Appears only when there is more than one answer.) Selects the answer to build a proof for. |
| **No answer: build the proof that this query FAILS** | (Appears only for a query with no answer.) Tells you that the full board is in failing mode. Refer to §6.1. |
| **Child Mode (Hide Text)** | Hides all the words and shows only coloured shapes. Thus students match cards by **colour and structure**, not by reading. Good for younger students, and to show the *shape* of a proof. Keep the box clear to keep all the words. |
| **Clone Tool** | (Appears only when necessary.) Click to make it active, then click a card to make a copy of it. |
| **Show Proof** | Builds the full proof automatically: the "answer key". Use it to demonstrate, to examine the attempt of a student, or to show a failure tree that is difficult to find. |
| **Auto Layout** | Puts the cards in a tree that is easy to read. |
| **Predicates Legend** | Shows a list of the predicates, each with its colour. |
| **+ / − / ⛶** | Zoom in, zoom out, and fit the board to the screen. |
| **Theme** | Dark, light, or high-contrast. |

When you click a card, the editor also **highlights the related text**. Thus the class
can connect the puzzle piece to the rule or fact that it came from.

---

## 10. A suggested lesson plan

A lesson of 30–40 minutes with `happy_dragon.le`:

1. **Warm-up (positive proof).** Load the `smoky` scenario and the query `happy`.
   Select the answer **"bob is happy."** Ask the class to connect cards from the query
   down to facts. Explain **matching/bindings** during this work. Let a **clash**
   occur intentionally, and discuss why it is wrong.
2. **"forall" conditions.** Show the *"for all cases"* condition and its two sockets.
   Discuss what it means to examine a claim "for each case."
3. **Change the answer.** Change "Answer to prove" to **"alice is happy."** The board
   looks almost the same, but now there is a *negation* to satisfy.
4. **Negation, the easy way.** Satisfy *"it is not the case that bob smokes"* with a
   **FAIL** card. The proof is complete. Ask: *but why does bob not smoke?*
5. **Negation, the real way.** Remove the FAIL card. Connect the **smoking rule** to
   the negation. (Show the label *"not the case"* and the change of colour to failing
   mode.) Use the **Clone Tool** to apply the smoking rule again for *alice*. Continue
   to a **FAIL leaf**. Discuss why, to prove *false*, **all** ways must fail.
6. **Show the answer.** Click **Show Proof**, and compare the result with the attempt
   of the class.

---

## 11. Concept glossary for the classroom

- **Query**: the question that we try to answer.
- **Rule**: "if these conditions are true, then this conclusion is true."
- **Fact**: something that is true in the selected scenario.
- **Variable**: a placeholder such as *"a creature"*. A variable can be different
  individuals.
- **Binding / matching (unification)**: when you connect cards, a variable gets a
  specific value. This is the base of all the reasoning.
- **Clash**: a contradiction. A variable must be two different things at the same
  time.
- **Proof tree**: the query at the top, the rules in the middle, the facts at the
  bottom.
- **Negation as failure**: something is "not true" exactly when each attempt to prove
  it **fails**. You play a query with no answer in this way, as one full failure
  (§6.1).
- **Assumption / abduction**: you cannot prove an assumable statement. You can only
  **assume** it. When you use it, you explain an observation with a hypothesis ("the
  grass is wet **if we assume** it rained").
- **Failing mode**: a rule in dark red. The rule explains a failure, not a success.
- **"for all cases"**: a claim that must be true for each applicable case.

---

*Tip:* Start in **Child Mode**, to show the *shape* of a proof. Then show the text, to
connect that shape to the real Logical English sentences. The same board is good for
a first lesson about reasoning, and also for a serious discussion of negation and
quantification.
