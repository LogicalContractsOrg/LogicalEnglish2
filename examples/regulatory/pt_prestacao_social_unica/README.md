# Portugal's single social benefit (prestação social única), in Português Lógico

*Kind: example · Audience: readers of rules for public services · Status: written 14 October 2026*

**Resumo.** Este programa escreve em Português Lógico — a versão portuguesa
do Logical English — as regras centrais da prestação social única (PSU),
criada pelo Decreto-Lei n.º 166/2026, de 13 de agosto, que produz efeitos a
31 de dezembro de 2026: quem a pode receber, o agregado familiar, os
rendimentos que contam, o limite do património, o montante base, a
componente de incentivo ao trabalho, as majorações e o teto. Cada regra cita
o artigo, o número e a alínea de onde vem. Foi escrito à mão, com um agente
de IA, a partir do texto publicado; não verificado contra o sistema da
Segurança Social. As respostas esperadas dos doze cenários foram calculadas
à mão a partir do decreto, antes de correr o programa. O programa é
fornecido "tal como está" e não é aconselhamento jurídico.

## What this is

On 13 August 2026 Portugal published Decree-Law 166/2026 (*Decreto-Lei*, a law
made by the Government). From 31 December 2026 it replaces several benefits
for people with little or no money, such as the social integration income
(*rendimento social de inserção*), with one benefit: the **single social
benefit** (*prestação social única*, PSU). The PSU tops up what a household
(*agregado familiar*, the people who live and share their resources with the
person who applies) already receives to a minimum level.

This folder holds the rules of the decree that decide **who is entitled, and
to how much**, written in **Português Lógico**: the Portuguese version of
Logical English, rules in plain Portuguese sentences that a computer runs,
giving the reasons for every answer. The program is in
[prestacao_social_unica.le](prestacao_social_unica.le).

A few words used below:

- A **template** is the pattern of a sentence, with a blank for each thing that
  varies, such as *a idade de \*uma pessoa\* é \*um número\** ("the age of a
  person is a number").
- A **scenario** (*cenário*) is a named set of facts that describes one case:
  one applicant and the people they live with.
- A **query** (*consulta*) is a question put to the program, such as "what is
  the monthly amount of the PSU of which applicant".
- An **expected answer** is the answer a scenario says a query should give.
  The test runner checks every expected answer.
- The **IAS** (*indexante dos apoios sociais*, the social support index) is
  the reference amount that Portuguese benefits are measured in. For 2026 it
  is 537.13 euros (Portaria n.º 480-A/2025/1, of 30 December 2025; a
  *portaria* is a ministerial order).

## Try it

- Open [prestacao_social_unica.le](prestacao_social_unica.le?scenario=casal_com_filhos&query=montante)
  and press **Query**. The answer is *o montante mensal da prestação social
  única de bruno é 519,26*: 519.26 euros a month for a couple with two
  children, where the wife earns a part-time wage. Click the answer: each step
  names the article of the decree it comes from.
- Run the query **incentivo** on the same scenario
  ([link](prestacao_social_unica.le?scenario=casal_com_filhos&query=incentivo)):
  313.30 euros of the wage are not taken away from the benefit. This is the
  work incentive component (*componente de incentivo ao trabalho*, article
  28): the household's earnings up to 20 % of the IAS in full, and half of
  the earnings above that.
- Choose the scenario **patrimonio_excessivo** and run **indeferimento**
  ([link](prestacao_social_unica.le?scenario=patrimonio_excessivo&query=indeferimento)):
  the application is refused for *património_mobiliário*. The applicant has
  40,000 euros in the bank, more than 60 times the IAS (32,227.80 euros),
  article 8, number 1, paragraph c).
- Choose **idoso** and run **agregado**
  ([link](prestacao_social_unica.le?scenario=idoso&query=agregado)): a man
  above the pension age lives with his wife and their adult son, but his
  household is only himself and his wife (article 5, number 5). The son's
  wage does not count.
- Choose **habitacao_e_imoveis** and run **indeferimento**
  ([link](prestacao_social_unica.le?scenario=habitacao_e_imoveis&query=indeferimento)):
  the applicant passes every condition, but the benefit would be 8.99 euros,
  and below 10 euros nothing is paid (article 25, number 5).
- The program has a **view** (*vista*) for a caseworker of Social Security
  (*Segurança Social*), *balcão da segurança social*: a screen with the facts
  of a case in four groups, the monthly amount in large type, a banner
  when the application is refused, the reasons and the articles behind them,
  and a draft of the decision letter. Open it with **Misc ▸ Open Executive
  View**.

The ten queries are `direito` (who is entitled), `montante` (the monthly
amount), `indeferimento` (why an application is refused), `base` (the base
amount), `adultos_equivalentes` (the household's size in "equivalent
adults"), `rendimentos` (the household's monthly income), `incentivo` (the
work incentive component), `global` (the amount before any increase),
`majoração` (an increase for parents or for the unemployed), and `agregado`
(who is in the household).

## What the program covers

75 rules, each labelled with the article, number and paragraph it comes from,
and a short quotation of that passage. The quotations are checked by the
program's checker against the text of the decree, which is kept beside the
program.

| Part of the decree | What the rules decide |
|---|---|
| Article 4 | the applicant is 18 or over, or an orphan under 18 in care |
| Article 5 | who is in the household: the spouse or partner, relatives up to the third degree who are adults, relatives who are children, children in the household's care; not lodgers, not people staying for a short time; for an applicant above the pension age, only the spouse or partner |
| Articles 8 and 9 | the general conditions: living in Portugal (Portuguese citizens; citizens of the European Union and similar countries; others with a residence permit for at least a year; refugees and stateless people), income below the base amount, savings and investments (*património mobiliário*) and registered goods such as cars each at most 60 times the IAS, no job left by one's own choice in the past year (unless the applicant is a recognised victim of domestic violence), not in prison (except in the 45 days before release), no asylum support, and everyone's consent to checks of their tax and bank data |
| Articles 10 to 17 | the income that counts, per month: wages after social contributions and income tax withheld, plus a twelfth of the holiday and Christmas pay; self-employed income declared for the last quarter, divided by three; interest, counted as at least 3 % (or the 12-month EURIBOR, the euro interbank rate, plus 1 point) of savings above 15 times the IAS; rents, counted as at least 5 % of a property's value, and the family home only above 450 times the IAS; pensions with a twelfth of their holiday and Christmas pay; other regular benefits, but not those for children, disability or dependency; help with housing, valued as half the difference between a reference rent and the rent paid in social housing |
| Articles 18 and 20 | people of working age who do not work must be registered at a job centre and be available for work and for social solidarity activities; those aged 18 to 25 also for extra hours; the exemptions (temporary sickness, certain pensions, a disability of 80 % or more, or of 60 % to 80 % when assessed as incompatible, students, main informal carers) |
| Article 24 | the base amount: half the IAS times the household's equivalent adults (1 for the applicant, 0.7 for each other adult, 0.5 for each child) |
| Articles 25 and 28 | the amount: base amount plus work incentive component minus income; the ceiling of 6 times the IAS for all the household's non-contributory benefits (disability and dependency benefits apart); nothing below 10 euros |
| Articles 26 and 27 | the increase for a parent without parental pay, and the increase for an unemployed person without unemployment pay, which bring the amount up to 80 % of the IAS |

## What is left out

The program decides an application on the facts at the date it is made. It
leaves out:

- the procedure: how to apply, deadlines, evidence, decisions, renewals
  (articles 30 to 33), except the rule that an application is refused when a
  condition fails (article 31, number 4);
- the duties of people who receive the benefit, the job centre's duties, the
  individual integration plan and the follow-up (articles 19, 21 to 23 and 34
  to 36);
- suspension, review and ending of the benefit (articles 37 to 41), and the
  penalties (articles 42 to 44);
- the changes the decree makes to other laws (articles 45 to 56) and the
  transitional rules for people who received the old benefits (articles 57 to
  61).

Some facts are entered already worked out, because the decree takes them from
other laws or from records that the program does not hold: the
"relevant income" of a self-employed worker (from the Contributory Code), the
normal pension age (set each year by ministerial order; here it is a fact of
the case, *atingiu a idade normal de acesso à pensão de velhice*, "has reached
the normal pension age"), the 12-month EURIBOR, and the median rent per square
metre published by Statistics Portugal (INE). The decree does not refer to
the older means-test law, Decree-Law 70/2010, for any of its definitions: it
defines its own household and income (articles 5 and 10 to 17), so nothing
from Decree-Law 70/2010 is encoded.

## Where the reading had to choose

The decree was read as printed. In these places the text allows more than one
reading, and the program makes a choice that a lawyer should check:

1. **The income test compares income with the base amount, without the work
   incentive.** Article 8, number 1, paragraph b) asks that income be below
   "the value of the PSU, calculated under number 1 of article 24", which is
   the base amount alone. So a household whose wages are above the base amount
   is refused, even though the formula of article 25 would still give it a
   positive amount.
2. **Savings of 15 times the IAS or less produce no capital income at all.**
   Article 13, number 6 says that only financial assets that "in their
   totality exceed 15 times the IAS" count. The program reads this for the
   household's total, and as removing the interest actually received as well
   as the presumed interest.
3. **Both increases at once.** Article 25, number 2 adds "an increase for
   parenthood or an increase for unemployment". The decree does not say which
   applies when a household could have both; the program gives the higher one.
   Increases for parenthood for two different people are added together.
4. **The alleged aggressor's wages** (article 10, number 2) count neither in
   the income nor in the work incentive, since the article says they are "not
   considered" for the amount of the benefit.
5. **Rounding.** The decree does not say how amounts are rounded. The program
   rounds the base amount, the work incentive, the income, the increases and
   the final amount to the nearest cent, half a cent upwards.
6. **The ceiling** (article 25, number 3) is read as a limit on all the
   non-contributory benefits of the household together, so the benefit is at
   most 6 times the IAS minus the household's other non-contributory
   benefits. A benefit is marked non-contributory as a fact of the case.
7. **Ages 18 to 25** (article 18, number 2) are read as up to the day before
   the 26th birthday.
8. **The value of savings** is one figure for each person, used both for the
   limit of article 8 and for the presumed interest of article 13 (which
   speaks of the value on 31 December of the year before).

## How it was made, and how it was checked

The program was written by hand, with an AI agent, from the published text of
the decree. It has **not** been checked against the Social Security's own
systems, which are not public.

The expected answers were worked out **separately**, by hand, from the text of
the decree, before the program was run. The working is a short calculation
for each scenario (for example, for the couple with two children: wage 500 −
55 + 890 ÷ 12 = 519.17; equivalent adults 1 + 0.7 + 0.5 + 0.5 = 2.7; base
amount 268.565 × 2.7 = 725.13; work incentive 107.426 + (519.17 − 107.426) ÷
2 = 313.30; benefit 725.13 + 313.30 − 519.17 = 519.26). The program's
comments above each scenario repeat that working.

The program then gave the same answer as the hand calculation for every
expectation, once three faults in the program itself were corrected. None of
them came from reading the decree differently:

- a fact with a label (the IAS, labelled with its ministerial order) stopped
  the whole knowledge base from being read; the IAS is now the conclusion of a
  labelled rule;
- the built-in sentences *o mínimo de … e … é …* and *o máximo de … e … é …*
  ("the minimum of … and … is …") gave no answer when one of their numbers was
  a calculation, which left the capital income, the property income, the
  interest rate and the final amount without an answer; each calculation is
  now done first;
- two sums over the household were moved to the household level, so that each
  sum names the household it adds up.

There are 12 scenarios with 67 expected answers, covering: a person alone; a
couple with children where one partner works; refusal for income; refusal for
savings; an applicant above the pension age; refusal because a young adult in
the household is not available for the extra hours; the increase for
unemployment; the increase for parenthood with a partner who works; social
housing and land that pays no rent, ending below 10 euros; a large family at
the ceiling; refusal for residence and for leaving a job; and a victim of
domestic violence who left her job, with the alleged aggressor's wages left
out. All 67 pass.

To run them:

```
./myswipl.sh -g "use_module(le_kbs), runTestsFor('examples/regulatory/pt_prestacao_social_unica/prestacao_social_unica.le', R), print_test_result(R), halt."
```

## The files

| File | What it is |
|---|---|
| `prestacao_social_unica.le` | the program: 75 rules, 12 scenarios with their expected answers, 10 queries and one view |
| `decreto_lei_166_2026.pdf` | the decree as published in the *Diário da República*, 1st series, no. 156, 13 August 2026 |
| `decreto_lei_166_2026.txt` | the text of the decree, taken from the PDF, which the checker uses to find each rule's quotation |

## Source, licence and disclaimer

Source: Decreto-Lei n.º 166/2026, de 13 de agosto, *Diário da República*,
1.ª série, n.º 156,
<https://diariodarepublica.pt/dr/detalhe/decreto-lei/166-2026-1156670556>
(PDF: <https://files.diariodarepublica.pt/1s/2026/08/15600/0001100041.pdf>).
The IAS for 2026 is set by Portaria n.º 480-A/2025/1, de 30 de dezembro.

Legal texts are not protected by copyright in Portugal (Código do Direito de
Autor e dos Direitos Conexos, article 7), so the decree's text is reproduced
here in full.

The program is provided "as is", without warranty of any kind. It is not
legal advice and not an official tool of the Social Security: check it
against the decree, and ask the Social Security, before relying on it.
