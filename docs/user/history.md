# A short history of Logical English and Logic Production Systems

*Logical English* is a way of writing rules in English that a computer can run,
with the reasons for every answer. *Logic Production Systems* (LPS) runs
programs that act over time, such as contracts and processes. They did not appear overnight; this page lines up some history.

## TLDR;

> Logical English and Logic Production Systems come out of forty years of
> research on logic programming at Imperial College London, and have been used since 2017 on projects on tax rules, derivatives
> contracts and insurance policies. Their 2026 versions are open source and run
> in a web browser.

## Summary

> Logical English and Logic Production Systems come out of forty years of
> research on logic programming at Imperial College London, led by Robert
> Kowalski, one of the founders of logic programming. In 1986 his group implemented a large portion of the
> British Nationality Act as a logic program, one of the first laws ever run by
> a computer. Logic Production Systems was first prototyped in 2013 as a student project at Imperial College, and then implemented in 2015 and 2016;
> Logical English in 2020. Since 2017 Logical Contracts has built both
> languages into working systems, used in projects on tax rules for LodgeIT in
> Australia and AORA Law in the United Kingdom, on derivatives contracts with
> D2 Legal Technology, and on insurance policies with Axiome Partners. In 2026
> both languages were rewritten from the ground up and released as open source,
> as Logical English (LE2) and LPS2, which run in a web browser and also read (convert) the
> programs of seventeen other rule systems.

## Timeline

### The research behind the languages

- **1972.** First version of the logic programming language Prolog, based on Robert Kowalski's procedural interpretation of Horn clauses. Developed and implemented by Alain Colmerauer's team in Marseille. Computation in Prolog uses backward reasoning with Horn clauses of the form conclusion if conditions as problem-solving procedures, to reduce goals that unify with conclusions to subgoals that match the conditions. 
  ([The Marseille-Edinburgh Connection](http://www.doc.ic.ac.uk/~rak/papers/Marseille-Edinburgh.pdf), 2024)
- **1974.** R. Kowalski, Predicate Logic as Programming Language, Proceedings IFIP Congress, Stockholm, North Holland Publishing Co. The first full description of logic programming.
- **1976.** M. van Emden and R. Kowalski, *The Semantics of Predicate Logic as a
  Programming Language*, Journal of the ACM 23(4). This work presents the meaning of a
  logic program in three equivalent mathematical formulations.
- **1979.** R. Kowalski, Logic for Problem Solving, Artificial intelligence series 7, North-Holland. “An introduction to logic, the theory of problem-solving,  and computer programming.”
Also R. Kowalski, Algorithm = Logic + Control, Argues that an algorithm can be regarded as combining a logic component, which specifies domain-specific knowledge, with a control component, which employs general-purpose strategies to use that knowledge to solve goals in the problem domain.
- **1986.** M. Sergot, F. Sadri, R. Kowalski, F. Kriwaczek, P. Hammond and
  T. Cory, [*The British Nationality Act as a Logic Program*](http://www.doc.ic.ac.uk/~rak/papers/British%20Nationality%20Act.pdf),
  Communications of the ACM 29(5). One of the first laws written as a computer program
  that a computer runs. The original program was recovered in 2026 from an old
  disk image, and runs in Logical English 2 among its examples
  (`examples/regulatory/bna.le`). 
  Also R. Kowalski and M. Sergot, A Logic-based Calculus of Events, New Generation Computing. The Event Calculus distinction between fluents, which represent states as a database of time-varying facts, and events, which generate state transitions, is one of the foundations of LPS.
- **1987.** First version of SWI-Prolog, by Jan Wielemaker
- **1988.** F. Sadri and R. Kowalski, A theorem-proving approach to database integrity, Foundations of deductive databases and logic programming, Morgan Kaufmann. The use of forward reasoning, to check the integrity of database updates, is another of the main foundations of LPS.
- **1992.** R. Kowalski, [*Legislation as Logic Programs*](http://www.doc.ic.ac.uk/~rak/papers/law.pdf),
  in *Logic Programming in Action*, Springer. Introduced an early, but unimplemented, version of Logical English as syntactic sugar for logic programs.
Also A. C. Kakas, R. Kowalski and
  F. Toni, [*Abductive Logic Programming*](http://www.doc.ic.ac.uk/~rak/papers/abdsurv.pdf),
  Journal of Logic and Computation 2(6). Abductive logic programming (ALP), combines backward reasoning, to generate candidate assumptions to solve goals, with forward reasoning, to check the integrity of assumptions. ALP is the third main foundation of LPS.
- **2011.** R. Kowalski, *Computational Logic and Human Thinking: How to be
  Artificially Intelligent*, Cambridge University Press. The book argues that many of the advances in the development of Computational Logic for Artificial Intelligence can also be used directly by people, to improve their own human intelligence.
- **2014.** R. Kowalski, [*History of Logic Programming*](http://www.doc.ic.ac.uk/~rak/papers/History.pdf),
  in *Computational Logic*, volume 9 of the Handbook of the History of Logic,
  Elsevier.

### Logic Production Systems, and the first implementations

- **2015.** R. Kowalski and F. Sadri, [*Reactive Computing as Model Generation*](http://www.doc.ic.ac.uk/~rak/papers/LPS%20revision.pdf),
  New Generation Computing 33(1). The first full description of LPS. LPS can be viewed as a special case of ALP, where logic programs represent an active database of states and state transitions, and integrity constraints represent goals that need to be satisfied by generating actions in response to updates which record external events. 
- **2016.** R. Kowalski and F. Sadri, [*Programming in Logic without Logic Programming*](http://www.doc.ic.ac.uk/~rak/papers/KELPS%202015.pdf),
  Theory and Practice of Logic Programming 16(3).
- **2016–2017.** The first full implementation of LPS by Miguel Calejo, written in SWI-Prolog and run
  in SWISH, a web site where Prolog programs are written and run in the
  browser. It was built as part of the project CLOUT (Computational Logic for Use in Teaching), a
  project funded by Imperial College London to teach computing and logic in
  schools. Its source code is on [Bitbucket](https://bitbucket.org/lpsmasters/lps_corner).
  A second implementation, [lps.js](https://lps.js.org/), was written in
  JavaScript by Sam Yong for his master's degree at Imperial College. Both are
  listed on the [LPS site at Imperial College](http://lps.doc.ic.ac.uk).
- **2017.** Logical Contracts extends LPS into the *Logical Contracts Server*,
  for contracts that run on their own, including on the Ethereum blockchain.
  It came with an early version of Logical English, called *Formal English* developed and implemented by Jacinto Dávila: an LPS program could carry a specification in
  English, which the server turned into rules that run, and any LPS program
  could be printed back in Formal English. Formal English was the first step towards
  Logical English. Logical Contracts showed the server at the Web Summit in
  Lisbon, in November 2017.
- **2017–2018.**  LPS tutorial at the RuleML+RR 2017 conference by Kowalski, Sadri and Calejo. In 2018
  Logical Contracts sponsored RuleML+RR in Luxembourg, where the tutorial
  *Logic and Smart Contracts* used the open-source Logical Contracts Server.
- **2019.** J. Wielemaker, F. Riguzzi, R. Kowalski, T. Lager, F. Sadri and
  M. Calejo, [*Using SWISH to Realise Interactive Web-based Tutorials for Logic-based Languages*](http://www.doc.ic.ac.uk/~rak/papers/swish.pdf),
  Theory and Practice of Logic Programming 19(2).

### Logical English, and the first client projects

- **2020.** R. Kowalski, [*Logical English*](http://www.doc.ic.ac.uk/~rak/papers/LPOP.pdf),
  position paper at LPOP 2020 (Logic and Practice of Programming). The
  language is named and described.
- **2020–2021. LodgeIT (Australia) and AORA Law (United Kingdom).** Logical
  Contracts (Miguel Calejo, Jacinto Dávila, Robert Kowalski) builds *TaxLog* and its tax knowledge base for two sponsors. For
  LodgeIT, an Australian tax software company, it encodes the small business
  concessions of Australia's capital gains tax. For AORA Law, a United Kingdom
  firm, it encodes the reliefs of the stamp duty reserve tax, the statutory
  residence test and the research and development tax reliefs. TaxLog was the
  first implementation of a Logical English written on top of (SWI) Prolog.
- **2021.** J. Dávila, M. Calejo and R. Kowalski, [*Logical English for Legal Applications*](http://www.doc.ic.ac.uk/~rak/papers/LE_for_LA.pdf),
  XAIF Virtual Workshop on Explainable AI in Finance.
- **2021. D2 Legal Technology (United Kingdom).** A. Datoo and R. Kowalski,
  [*Logical English Meets Legal English for Swaps and Derivatives*](http://www.doc.ic.ac.uk/~rak/papers/Logical%20English%20meets%20Legal%20English.pdf),
  Artificial Intelligence and Law. With D2 Legal Technology, Logical Contracts
  wrote parts of the ISDA Master Agreement, the standard contract for
  derivatives, as Logical English.
- **2021 onwards.** The first implementation of Logical English is published
  on GitHub as open source, under the Apache 2.0 licence:
  [LogicalContractsOrg/LogicalEnglish](https://github.com/LogicalContractsOrg/LogicalEnglish),
  with a demonstration site at <https://logicalenglish.logicalcontracts.com/>.
  Its copyright holders are LodgeIT, AORA Law, Robert Kowalski, Miguel Calejo
  and Jacinto Dávila. The University of Bologna and the European University
  Institute in Florence supported its later development.
- **2023.** Two chapters in *Prolog: The Next 50 Years*, Lecture Notes in
  Computer Science 13900, Springer:
  J. Dávila, G. Sartor, M. Calejo and R. Kowalski, [*Logical English for Law and Education*](http://www.doc.ic.ac.uk/~rak/papers/Logical%20English%20for%20Law%20and%20Education%20.pdf);
  and F. Sadri, M. Calejo, J. Dávila and R. Kowalski, [*Combining Logic Programming and Imperative Programming in LPS*](http://www.doc.ic.ac.uk/~rak/papers/Combining%20LP%20and%20IP%20in%20LPS.pdf).
  Also J. Dávila and R. Kowalski, [*Logical English Demonstration*](http://www.doc.ic.ac.uk/~rak/papers/Logical_English_Demonstration_for_ICLP.pdf),
  39th International Conference on Logic Programming.
- **2024. Axiome Partners (United Kingdom).** J. Cummins, J. Dávila, D. Ovenden
  and R. Kowalski, [*Computable Contracts for Insurance: Establishing an Insurance-Specific Controlled Natural Language, InsurLE*](http://www.doc.ic.ac.uk/~rak/papers/InsurLE.pdf),
  The British Insurance Law Association Journal 136. InsurLE extends Logical
  English with the devices of insurance wording; Logical Contracts develops
  Logical English for Axiome Partners, which licenses InsurLE.

### The new implementations

- **March 2026.** M. Calejo, [*Can we vibe code financial contracts?*](https://www.jibfl.co.uk/articles/can-we-vibe-code-financial-contracts-),
  Butterworths Journal of International Banking and Financial Law, March 2026,
  pages 162–164. How an LLM and Logical English can work together to
  turn contract wording into a program that a lawyer can read without technical training.
- **April 2026.** Work starts on Logical English 2 (LE2), a new implementation
  written from the ground up by Miguel Calejo with Claude Code, fully compatible with the previous versions: [LogicalContractsOrg/LogicalEnglish2](https://github.com/LogicalContractsOrg/LogicalEnglish2).
  It has its own editor in the browser, explains every answer, keeps tests
  inside the program, and works in five languages (English, Portuguese,
  Spanish, French and Italian).
- **May 2026.** Work starts on LPS2, the new implementation of Logic
  Production Systems, written in Logical English or in LPS:
  [LogicalContractsOrg/lps2](https://github.com/LogicalContractsOrg/lps2). Provides multiple visualisations, and runs the programs of the first LPS.
- **July 2026.** Preview of Logical English 2 at [Workshop of the Prolog Education Group](https://prolog-lang.org/Education/PrologEducationWS2026.html), ICLP
- **3 October 2026.** Logical English 2 and LPS 2 launched as open source, under the
  Apache 2.0 licence. Both systems run in the browser, with nothing to install:
  <https://le2.logicalcontracts.com> and <https://lps2.logicalcontracts.com/ide>.
- **October 2026.** The Logical English Translators,
  which read the programs of seventeen other rule systems into Logical
  English, are offered to organisations.
