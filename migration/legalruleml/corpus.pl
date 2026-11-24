/** <module> The LegalRuleML corpus: the specification's examples, reviewed

    The fifteen examples of the LegalRuleML Core Specification (corpus/oasis,
    both serialisations; the normalized one is translated, the compact one
    must read to the same model). LegalRuleML ships no tests, so each example
    the translator can say something about gets:

      - the reviewer's wording of its relations (where the document's names
        are not English: `engageCreditActivity`), recorded in the ledger as
        the reviewer's, not the translator's;
      - scenarios drafted from its paraphrases and from the law it encodes,
        whose expected answers are SPINdle's on the source (lrml_spindle.pl).

    The schematic examples (rel1, rel2, ...) keep their naive wording; what
    they test is the structure (defeaters, overrides, alternatives, CURIEs).
    ex4, ex6 and ex7 hold metadata only (no statements) and are read, not
    translated.
*/

:- module(legalruleml_corpus, [lrml_example/3, corpus_dir/1]).

:- prolog_load_context(directory, D), atomic_list_concat([D, '/corpus/oasis'], O),
   retractall(corpus_dir_(_)), assertz(corpus_dir_(O)).
:- dynamic corpus_dir_/1.

corpus_dir(D) :- corpus_dir_(D).

%!  lrml_example(?Base, -File, -Options) is nondet.
lrml_example(Base, File, Options) :-
    example(Base, Options),
    corpus_dir(D),
    atomic_list_concat([D, '/', Base, '-normal.lrml'], File).

example('ex1-curies', []).
example('ex2-references', []).
example('ex3-deontic', [scenarios([
    scenario(permitted_and_obliged, [rel1(x), rel2(x)],
             [comment("Only the facts: nothing is violated, so ps1 and ps2 (which need a violation of ps0, a statement the document lacks) do not apply.")])
  ]),
  ledger_notes(['Override ps2 over ps1'-"The document's statements depend on one another through negation, and the verifier says so (non_stratified): ps2 overrides ps1, so once ps2's prohibition is violated its next element keeps ps1 from applying; and ps1's reparations (rep1, rep3) oblige what ps2 forbids. SPINdle settles such a loop by the superiority of its rules; the twin states it as it is. The scenario violates nothing, so the loop is never entered."])]).
example('ex5-section29new', [
    wording([person-"*a person* is a person",
             engageCreditActivity-"*a person* engages in a credit activity",
             hasLicence-"*a person* holds a credit licence",
             payCivilUnits-"*a person* pays *a number* civil penalty units",
             payPenalUnits-"*a person* pays *a number* penalty units",
             imprisonment-"*a person* is imprisoned for *a term*",
             payPebnalUnitPlusImprisonment-"*a person* pays *a number* penalty units and is imprisoned for *a term*"]),
    scenarios([
      scenario(unlicensed_trader, [person(alice), engageCreditActivity(alice), payPenalUnits(alice, 200)],
               [comment("s. 29(1): a person must not engage in a credit activity without a licence. Alice does, and pays the 200 penalty units but not the 2000 civil penalty units.")]),
      scenario(licensed_trader, [person(bob), engageCreditActivity(bob), hasLicence(bob)],
               [comment("s. 29(2): the prohibition does not apply to a licensee.")]),
      scenario(no_activity, [person(carol)],
               [comment("The prohibition holds, and nothing violates it.")]),
      scenario(defaulter, [person(dave), engageCreditActivity(dave), payCivilUnits(dave, 2000)],
               [comment("Dave pays the civil penalty but not the penalty units: the suborder list runs on to imprisonment, and then to both.")])
    ])]).
example('ex8-defeasible', [scenarios([
    scenario(both_conditions, [rel1(x), rel2(x)], []),
    scenario(one_condition, [rel1(x)], [])
  ])]).
example('ex8b-defeasible', [scenarios([ scenario(both_conditions, [rel1(x), rel2(x)], []) ])]).
example('ex8c-defeasible', [scenarios([ scenario(both_conditions, [rel1(x), rel2(x)], []) ])]).
example('ex9-alternatives', []).
example('ex9b-alternatives', [scenarios([
    scenario(prescriptive_reading, ['A'], [alternative(ps1)]),
    scenario(constitutive_reading, ['A'], [alternative(cs2)])
  ])]).
example('ex10-mix', []).
example('ex11-maternity_alternatives', [
    wording([earned-"*an income* is earned in *a year*",
             reported-"*an income* is reported in *a year*",
             paybenefit-"the maternity benefit is *an amount* in *a year*"])]).
example('ex12-USC_17_504_context', [
    ledger_notes(['constitutive statement cs1'-"A rule with no conditions whose conclusion has a variable (lovo:Infringer of Var infringer): in the document, everyone is an infringer. The twin says so (`a person is an infringer.`), and the verifier warns that the fact holds for everything (single_variable_fact): the document's, kept as it is."]),
    wording(['Infringer'-"*a person* is an infringer",
             claimStatutoryDamages-"*a copyright owner* elects statutory damages",
             claimStatutoryDamanges-"*a copyright owner* claims statutory damages",   % tblocks 2 and 3 misspell it: a relation of its own
             isNotEqual-"*a copyright owner* is not the same person as *an infringer*",
             isOwner-"*a copyright owner* owns the copyright in *a work*",
             isWork-"*a work* is a work protected by copyright",
             notUse-"*an infringer* uses *a work*",
             payStatutoryDamages-"statutory damages of between *a minimum* and *a maximum* are paid",
             payWillfullyInfringement-"increased statutory damages of between *a minimum* and *a maximum* are paid",
             payNotWillfullyInfringement-"reduced statutory damages of between *a minimum* and *a maximum* are paid",
             sustainBurdenProving-"*a party* sustains the burden of proof",
             willfullyInfringing-"*an infringer* infringed wilfully"]),
    scenarios([
      scenario(statutory_damages, [isWork(novel), isOwner(ann, novel), isNotEqual(ann, ben), notUse(ben, novel),
                                   claimStatutoryDamages(ann), claimStatutoryDamanges(ann)],
               [comment("17 USC 504(c)(1): the owner elects statutory damages instead of actual damages.")]),
      scenario(wilful_infringement, [isWork(novel), isOwner(ann, novel), isNotEqual(ann, ben), notUse(ben, novel),
                                     claimStatutoryDamages(ann), claimStatutoryDamanges(ann), sustainBurdenProving(ann), willfullyInfringing(ben)],
               [comment("17 USC 504(c)(2): the owner proves the infringement was wilful.")]),
      scenario(innocent_infringement, [isWork(novel), isOwner(ann, novel), isNotEqual(ann, ben), notUse(ben, novel),
                                       claimStatutoryDamages(ann), claimStatutoryDamanges(ann), sustainBurdenProving(ben)],
               [comment("17 USC 504(c)(2): the infringer proves it was not aware that its acts infringed.")]),
      scenario(own_work, [isWork(novel), isOwner(ann, novel), notUse(ann, novel)],
               [comment("The owner using its own work infringes nothing.")])
    ])]).
