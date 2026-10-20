# A short history of Logical English and Logic Production Systems

*Logical English* is a way to write rules in English that a computer can run. For
each answer, Logical English gives the reasons. *Logic Production Systems* (LPS)
runs programs that act over time, for example contracts and processes. These two
languages did not appear in a short time. This page gives some of their history in
order.

## TLDR;

> Logical English and Logic Production Systems come from forty years of research on
> logic programming at Imperial College London. Since 2017, projects on tax rules,
> derivatives contracts and insurance policies have used them. Their 2026 versions
> are open source and run in a web browser.

## Summary

> Logical English and Logic Production Systems come from forty years of research on
> logic programming at Imperial College London. Robert Kowalski led this research. He
> is one of the founders of logic programming. In 1986, his group implemented a large
> part of the British Nationality Act as a logic program. This was one of the first
> laws that a computer ever ran.
>
> The first prototype of Logic Production Systems was a student project at Imperial
> College in 2013. The implementation followed in 2015 and 2016. Logical English
> followed in 2020. Since 2017, Logical Contracts has made both languages into
> working systems. Projects used these systems:
>
> - tax rules for LodgeIT in Australia and AORA Law in the United Kingdom,
> - derivatives contracts with D2 Legal Technology,
> - insurance policies with Axiome Partners.
>
> In 2026, both languages were written again from the start and released as open
> source, as Logical English (LE2) and LPS2. LE2 and LPS2 run in a web browser. They
> also read (convert) the programs of seventeen other rule systems.

## Timeline

### The research behind the languages

- **1972.** The first version of the logic programming language Prolog. Prolog uses
  the procedural interpretation of Horn clauses by Robert Kowalski. The team of Alain
  Colmerauer in Marseille developed and implemented Prolog. Computation in Prolog
  uses backward reasoning. It uses Horn clauses of the form "conclusion if
  conditions" as procedures to solve problems. These procedures reduce goals that
  unify with conclusions to subgoals that match the conditions.
  ([The Marseille-Edinburgh Connection](http://www.doc.ic.ac.uk/~rak/papers/Marseille-Edinburgh.pdf), 2024)
- **1974.** R. Kowalski, Predicate Logic as Programming Language, Proceedings IFIP
  Congress, Stockholm, North Holland Publishing Co. This paper is the first full
  description of logic programming.
- **1976.** M. van Emden and R. Kowalski, *The Semantics of Predicate Logic as a
  Programming Language*, Journal of the ACM 23(4). This work gives the meaning of a
  logic program in three equivalent mathematical forms.
- **1979.** R. Kowalski, Logic for Problem Solving, Artificial intelligence series 7,
  North-Holland. “An introduction to logic, the theory of problem-solving,  and computer programming.”
  Also R. Kowalski, Algorithm = Logic + Control. This paper says that an algorithm
  is a combination of two components. The logic component specifies the knowledge of
  a domain. The control component uses general strategies to apply that knowledge
  to the goals of the problem domain.
- **1986.** M. Sergot, F. Sadri, R. Kowalski, F. Kriwaczek, P. Hammond and
  T. Cory, [*The British Nationality Act as a Logic Program*](http://www.doc.ic.ac.uk/~rak/papers/British%20Nationality%20Act.pdf),
  Communications of the ACM 29(5). This was one of the first laws written as a
  program that a computer runs. In 2026, the original program was recovered from an
  old disk image. It runs in Logical English 2, among its examples
  (`examples/regulatory/bna.le`).
  Also R. Kowalski and M. Sergot, A Logic-based Calculus of Events, New Generation
  Computing. The Event Calculus makes a distinction between fluents and events.
  Fluents are states, kept as a database of facts that change over time. Events
  cause the changes from one state to the next. This distinction is one of the
  foundations of LPS.
- **1987.** The first version of SWI-Prolog, by Jan Wielemaker
- **1988.** F. Sadri and R. Kowalski, A theorem-proving approach to database
  integrity, Foundations of deductive databases and logic programming, Morgan
  Kaufmann. This work uses forward reasoning to check the integrity of database
  updates. Forward reasoning is another of the main foundations of LPS.
- **1992.** R. Kowalski, [*Legislation as Logic Programs*](http://www.doc.ic.ac.uk/~rak/papers/law.pdf),
  in *Logic Programming in Action*, Springer. This paper introduced an early version
  of Logical English, as a simpler syntax for logic programs. This version had no
  implementation.
  Also A. C. Kakas, R. Kowalski and
  F. Toni, [*Abductive Logic Programming*](http://www.doc.ic.ac.uk/~rak/papers/abdsurv.pdf),
  Journal of Logic and Computation 2(6). Abductive logic programming (ALP) combines
  two kinds of reasoning. Backward reasoning makes possible assumptions to solve
  goals. Forward reasoning checks the integrity of the assumptions. ALP is the third
  main foundation of LPS.
- **2011.** R. Kowalski, *Computational Logic and Human Thinking: How to be
  Artificially Intelligent*, Cambridge University Press. The book says that people
  can use directly many of the advances of Computational Logic for Artificial
  Intelligence. With these advances, people can improve their own human
  intelligence.
- **2014.** R. Kowalski, [*History of Logic Programming*](http://www.doc.ic.ac.uk/~rak/papers/History.pdf),
  in *Computational Logic*, volume 9 of the Handbook of the History of Logic,
  Elsevier.

### Logic Production Systems, and the first implementations

- **2015.** R. Kowalski and F. Sadri, [*Reactive Computing as Model Generation*](http://www.doc.ic.ac.uk/~rak/papers/LPS%20revision.pdf),
  New Generation Computing 33(1). This paper is the first full description of LPS.
  LPS is a special case of ALP. In LPS, logic programs are an active database of
  states and of changes between states. Integrity constraints are goals. The system
  satisfies these goals with actions. The actions are responses to updates that
  record external events.
- **2016.** R. Kowalski and F. Sadri, [*Programming in Logic without Logic Programming*](http://www.doc.ic.ac.uk/~rak/papers/KELPS%202015.pdf),
  Theory and Practice of Logic Programming 16(3).
- **2016–2017.** Miguel Calejo wrote the first full implementation of LPS. He wrote it
  in SWI-Prolog, and it ran in SWISH. SWISH is a web site where you write and run
  Prolog programs in the browser. This implementation was part of the project CLOUT
  (Computational Logic for Use in Teaching). Imperial College London funded CLOUT to
  teach computing and logic in schools. The source code is on
  [Bitbucket](https://bitbucket.org/lpsmasters/lps_corner). Sam Yong wrote a second
  implementation, [lps.js](https://lps.js.org/), in JavaScript, for his master's
  degree at Imperial College. The
  [LPS site at Imperial College](http://lps.doc.ic.ac.uk) lists both
  implementations.
- **2017.** Logical Contracts extends LPS into the *Logical Contracts Server*. The
  server runs contracts by themselves, also on the Ethereum blockchain. The server
  had an early version of Logical English, called *Formal English*. Jacinto Dávila
  developed and implemented Formal English. An LPS program could contain a
  specification in English. The server changed this specification into rules that
  run. The server could also print each LPS program back in Formal English. Formal
  English was the first step towards Logical English. Logical Contracts showed the
  server at the Web Summit in Lisbon, in November 2017.
- **2017–2018.** Kowalski, Sadri and Calejo gave an LPS tutorial at the RuleML+RR 2017
  conference. In 2018, Logical Contracts sponsored RuleML+RR in Luxembourg. There,
  the tutorial *Logic and Smart Contracts* used the open-source Logical Contracts
  Server.
- **2019.** J. Wielemaker, F. Riguzzi, R. Kowalski, T. Lager, F. Sadri and
  M. Calejo, [*Using SWISH to Realise Interactive Web-based Tutorials for Logic-based Languages*](http://www.doc.ic.ac.uk/~rak/papers/swish.pdf),
  Theory and Practice of Logic Programming 19(2).

### Logical English, and the first client projects

- **2020.** R. Kowalski, [*Logical English*](http://www.doc.ic.ac.uk/~rak/papers/LPOP.pdf),
  position paper at LPOP 2020 (Logic and Practice of Programming). This paper gives
  the language its name and describes it.
- **2020–2021. LodgeIT (Australia) and AORA Law (United Kingdom).** Logical Contracts
  (Miguel Calejo, Jacinto Dávila, Robert Kowalski) makes *TaxLog* and its tax
  knowledge base for two sponsors. LodgeIT is an Australian tax software company.
  For LodgeIT, TaxLog encodes the small business concessions of the capital gains
  tax of Australia. AORA Law is a firm in the United Kingdom. For AORA Law, TaxLog
  encodes the reliefs of the stamp duty reserve tax, the statutory residence test
  and the research and development tax reliefs. TaxLog was the first implementation
  of Logical English on top of (SWI) Prolog.
- **2021.** J. Dávila, M. Calejo and R. Kowalski, [*Logical English for Legal Applications*](http://www.doc.ic.ac.uk/~rak/papers/LE_for_LA.pdf),
  XAIF Virtual Workshop on Explainable AI in Finance.
- **2021. D2 Legal Technology (United Kingdom).** A. Datoo and R. Kowalski,
  [*Logical English Meets Legal English for Swaps and Derivatives*](http://www.doc.ic.ac.uk/~rak/papers/Logical%20English%20meets%20Legal%20English.pdf),
  Artificial Intelligence and Law. Logical Contracts and D2 Legal Technology wrote
  parts of the ISDA Master Agreement as Logical English. The ISDA Master Agreement
  is the standard contract for derivatives.
- **2021 onwards.** The first implementation of Logical English is published on
  GitHub as open source, with the Apache 2.0 licence:
  [LogicalContractsOrg/LogicalEnglish](https://github.com/LogicalContractsOrg/LogicalEnglish).
  It has a demonstration site at <https://logicalenglish.logicalcontracts.com/>.
  The copyright holders are LodgeIT, AORA Law, Robert Kowalski, Miguel Calejo and
  Jacinto Dávila. The University of Bologna and the European University Institute
  in Florence supported its later development.
- **2023.** Two chapters in *Prolog: The Next 50 Years*, Lecture Notes in
  Computer Science 13900, Springer:
  J. Dávila, G. Sartor, M. Calejo and R. Kowalski, [*Logical English for Law and Education*](http://www.doc.ic.ac.uk/~rak/papers/Logical%20English%20for%20Law%20and%20Education%20.pdf);
  and F. Sadri, M. Calejo, J. Dávila and R. Kowalski, [*Combining Logic Programming and Imperative Programming in LPS*](http://www.doc.ic.ac.uk/~rak/papers/Combining%20LP%20and%20IP%20in%20LPS.pdf).
  Also J. Dávila and R. Kowalski, [*Logical English Demonstration*](http://www.doc.ic.ac.uk/~rak/papers/Logical_English_Demonstration_for_ICLP.pdf),
  39th International Conference on Logic Programming.
- **2024. Axiome Partners (United Kingdom).** J. Cummins, J. Dávila, D. Ovenden
  and R. Kowalski, [*Computable Contracts for Insurance: Establishing an Insurance-Specific Controlled Natural Language, InsurLE*](http://www.doc.ic.ac.uk/~rak/papers/InsurLE.pdf),
  The British Insurance Law Association Journal 136. InsurLE adds the devices of
  insurance wording to Logical English. Logical Contracts develops Logical English
  for Axiome Partners. Axiome Partners licenses InsurLE.

### The new implementations

- **March 2026.** M. Calejo, [*Can we vibe code financial contracts?*](https://www.jibfl.co.uk/articles/can-we-vibe-code-financial-contracts-),
  Butterworths Journal of International Banking and Financial Law, March 2026,
  pages 162–164. This article tells how an LLM (large language model) and Logical
  English can work together. Together, they change contract wording into a program.
  A lawyer without technical training can read this program.
- **April 2026.** Work starts on Logical English 2 (LE2). LE2 is a new
  implementation, written from the start by Miguel Calejo with Claude Code, with
  help from Jacinto Dávila. LE2 is fully compatible with the previous versions:
  [LogicalContractsOrg/LogicalEnglish2](https://github.com/LogicalContractsOrg/LogicalEnglish2).
  LE2 has its own editor in the browser. It explains each answer and keeps tests
  inside the program. It operates in five languages (English, Portuguese, Spanish,
  French and Italian).
- **May 2026.** Work starts on LPS2, the new implementation of Logic Production
  Systems. You write LPS2 programs in Logical English or in LPS:
  [LogicalContractsOrg/lps2](https://github.com/LogicalContractsOrg/lps2). LPS2 gives
  many visualisations, and runs the programs of the first LPS.
- **July 2026.** Preview of Logical English 2 at the
  [Workshop of the Prolog Education Group](https://prolog-lang.org/Education/PrologEducationWS2026.html),
  ICLP
- **3 October 2026.** Logical English 2 and LPS 2 are released as open source, with
  the Apache 2.0 licence. Both systems run in the browser:
  <https://le2.logicalcontracts.com> and <https://lps2.logicalcontracts.com/ide>.
- **October 2026.** Logical Contracts offers the Logical English Translators to
  organisations. The Logical English Translators read the programs of seventeen
  other rule systems into Logical English.
- **December 2026.** Logical Contracts team gives tutorial at [JURIX](https://www.irit.fr/jurix2026/workshops-and-tutorials/): "Logical English as a Lingua Franca for Representing and Reasoning with Legal and Business Rules".