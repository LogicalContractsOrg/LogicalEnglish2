# The civil legal aid means test of England and Wales, in Logical English

*Kind: example · Audience: readers of rules for public services · Status: written 14 October 2026*

Legal aid pays for a lawyer for people who cannot afford one. In England and
Wales, a person who asks for civil legal aid (legal aid for a case that is not
a criminal case) must usually pass a **means test**: a check that their income
and their savings are low enough. The Legal Aid Agency runs the test. Its
rules are in a statutory instrument (a set of regulations made under an Act of
Parliament), the Civil Legal Aid (Financial Resources and Payment for
Services) Regulations 2013, in the guidance that the Lord Chancellor issues on
how to apply them, and in a short summary of the current figures that the
Agency calls a **keycard**.

This folder holds that means test written in **Logical English**: rules in
English that a computer runs, giving the reasons for every answer. Each rule
names the regulation, the paragraph of the guidance, or the line of the
keycard it was written from.

## Try it

- Open [civil_legal_aid_means.le](civil_legal_aid_means.le?scenario=pensioner_disregard&query=result) and press **Query**. The answer is *the means test result of jean is eligible under regulation 8(2) and (3)*. Jean is 67, has £45,000 of savings and a home, and lives on £380 a month. Click the answer: her savings would be over the £8,000 limit, but a person aged 60 or over on a low income keeps up to £100,000 of savings out of the count (regulation 41).
- Choose the scenario **homeowner_certificated** and run the query **disposable_capital**: *4100*. Then choose **homeowner_controlled**, the same household asking for a lower level of help, and run it again: *11000*, over the limit. The guidance for the higher level of help takes 3 per cent off the value of a home for the cost of selling it; the guidance for the lower level does not.
- Choose **large_family_over_gross** and run **gross_income_limit**: *2879*. The gross income limit of £2,657 a month rises by £222 for a fifth child, but this family's £2,927.48 is still over it, so it fails the test whatever its outgoings.
- In the executive view ([open it](/executive?program=regulatory%2Fuk_civil_legal_aid_means%2Fcivil_legal_aid_means&view=means%20assessment)), the screen *means assessment* shows a caseworker the client's facts, the result with its citations and reasons, the figures, and **Flip**, which lists the smallest changes to the facts that would change the result.

## What the program is

- **The facts of a case**, which a scenario states: the client and their age,
  the form of help asked for, the client's partner and dependants, each income
  received each month and its kind, each payment made each month (tax and
  National Insurance, childcare, maintenance, rent or mortgage), each sum of
  capital and its kind, and each property, with its value, its mortgage, the
  client's share, and whether it is the home or what the dispute is about.
- **The two levels of help.** *Certificated work* (legal representation in
  court, and family help at the higher level) is decided by the Legal Aid
  Agency. *Controlled work* (legal help, help at court, family help at the
  lower level, family mediation, and representation before some tribunals) is
  decided by the lawyer's firm. The means test is almost the same for both;
  the program shows the two differences that are simple to state: the 3 per
  cent off a property's value for the cost of selling it, and contributions
  (below), which were only ever asked for certificated work.
- **The rules**, in the order the keycard's step by step guide follows:
  - who is exempt: a child applying for legal representation is not means
    tested at all (regulation 5(1)(ba));
  - **passporting**: a person on Universal Credit or another "passporting"
    benefit passes the income tests without a calculation, but their capital
    is still tested (regulation 6(2) and (4)); a person on asylum support
    passes both tests for immigration and asylum help (regulation 6(1));
  - whose money counts: the client's and their partner's, unless the partner
    is on the other side of the dispute (regulation 16);
  - **gross income**, all income before deductions, less the benefits that are
    disregarded and housing benefit, against the limit of £2,657 a month,
    £222 higher for each child after the fourth (regulation 7);
  - **disposable income**, gross income less income tax and National
    Insurance, £45 for each person in work, the fixed allowances for a partner
    and each dependant, maintenance paid to someone outside the household,
    childcare while at work or study, housing costs (no more than £545 for a
    person with no partner and no dependants), and payments under a criminal
    legal aid contribution order, against the limit of £733 a month
    (regulations 23 to 29 and 8);
  - **disposable capital**, savings and other capital, plus the equity in each
    property, less the disregards: up to £100,000 of what the dispute is
    about, up to £100,000 of the equity in the home, and the pensioner's
    disregard of up to £100,000, against the limit of £8,000, or £3,000 for
    some immigration cases (regulations 30 to 41 and 8);
  - the result, with the regulation it rests on.
- **The figures of keycard 62** (April 2026) are in decision tables, one row a
  figure, each row quoting the line of the keycard it comes from. A decision
  table is a grid of rules, read one row at a time.
- 49 labelled rules and 6 decision tables. The text of every document the rules quote is in
  `sources/`, and the program checks each quotation against it.

## Which version of the rules

The rules are those in force on **14 October 2026**:

- The regulations as revised on legislation.gov.uk, in the version in force
  from 22 July 2026 (the latest amendment, S.I. 2026/861, changed only the
  list of cases with no means test).
- The limits have not changed since April 2013, and keycard 62 (April 2026)
  repeats them. The **Means Test Review**, the government's review of the
  test, proposed new and higher limits; they had not been made law by
  14 October 2026. The parts of the Review that are law are here: no means
  test for children asking for legal representation (since August 2023), and
  the disregards added in November 2024 (for example, arrears of benefits
  received in the last two years, and compensation payments).
- **Contributions are suspended.** Until 26 June 2025, some people who passed
  the test paid a monthly contribution from their income, or a lump sum from
  their capital, towards the cost of their case (regulation 44). After the
  Legal Aid Agency's computer systems were attacked in April 2025, the
  regulations were changed to remove contributions from 27 June 2025 (S.I.
  2025/750). In August 2026 the Agency's Means Assessment Guidance still says
  that contributions "remain temporarily waived" and that the Agency will
  assess means "but not request contributions". Keycard 62 and the Lord
  Chancellor's guidance of May 2025 still print the old contribution bands.
  So the program gives two answers for each contribution: what the old bands
  would set (`income_contribution`, `capital_contribution`), and what is
  payable today, which is nothing (`income_contribution_payable`,
  `capital_contribution_payable`).
- The **mortgage cap** (an upper limit on how much mortgage could be taken
  off a home's value) was removed in January 2021, so there is none here.

## How it was made, and how it was checked

The program was **written by hand with an AI agent from the published
regulations and guidance**. It is **not checked against the Legal Aid
Agency's system**, nor against the Agency's online eligibility checker.

The twelve scenarios (example cases) carry 77 expected answers. Each expected
answer was **worked out separately from the texts, by hand, before the
program was run**, not by running the program. When the program was first
run, every difference came from a mistake in the program, not in the hand
calculation (a minimum or maximum written over a sum, which the program
cannot work out in one step). Once that was corrected, the program agreed
with every hand calculation.

| Scenario | What it shows |
|---|---|
| `passported_universal_credit` | Universal Credit passes the income test; savings of £2,500 are under the limit |
| `child_applicant` | a 15-year-old asking for legal representation is not means tested |
| `over_disposable_income` | gross income under its limit, disposable income over its limit; the £545 housing cap |
| `eligible_no_contribution` | a couple with a child; carer's allowance and housing benefit left out of gross income |
| `eligible_with_income_contribution` | disposable income of £540: the old bands would set £87.65 a month, nothing is payable |
| `eligible_with_capital_contribution` | capital of £6,200: the old rules would take the likely cost of the case, £2,500, as it is less than the £3,200 over £3,000 |
| `passported_over_capital` | on Universal Credit but with £9,000 of savings: over the limit; a Windrush compensation payment is left out |
| `pensioner_disregard` | aged 67 with a low income: £70,000 of capital disregarded |
| `homeowner_certificated` | a home with £3,100 of equity left after 3 per cent off and the £100,000 home disregard |
| `homeowner_controlled` | the same home for legal help, without the 3 per cent: over the limit |
| `disputed_home` | a half share in a home that the dispute is about, with a partner on the other side (the guidance's own example 1 of paragraph 7.1) |
| `large_family_over_gross` | five children raise the gross income limit to £2,879, still under the family's income |

## Where a reading had to choose

- **Contributions.** Shown twice, as above, because the regulations and the
  guidance disagree on 14 October 2026.
- **The bands of the pensioner's disregard** are written in whole pounds
  ("£26-50"). An income in between, such as £25.50, is read as falling in the
  higher band. Regulation 41 asks for an income "less than" £315; the
  guidance writes "£315 per month or less". The regulation is followed.
- **A disposable income below nothing** (when the allowances are more than
  the income) is taken as nil.
- **A passported client's capital** is tested against £8,000, as regulation
  6(4)(a) says, even in the immigration cases where the limit for others is
  £3,000.
- **Negative equity** in a property counts as nothing; it does not reduce
  other capital.
- **Housing benefit** is left out of gross income and taken off the rent
  (regulations 7(1)(b) and 28(3)(a)).

## What is left out

- **What is pure procedure**: the evidence to be provided, the calculation
  period, further and amended determinations, reviews, emergency
  representation, the duty to report changes, and repayment of contributions.
- **What is left to the Director's judgement**, which the program takes as a
  fact of the case instead of deciding: whether a person is a partner or
  permanently separated, whether there is a contrary interest, what a
  reasonable amount for maintenance, childcare or accommodation is, whether a
  payment is to be disregarded under the discretionary disregards, and the
  likely maximum cost of a case.
- **The waivers of the limits** (multi-party actions of wider public
  interest, regulation 9, and protection from domestic abuse, female genital
  mutilation or forced marriage, regulation 12), which the Director may
  grant.
- **Business income and business capital** (regulations 22 and 36), trusts,
  life insurance, money owed to the client, and deprivation of resources
  (regulation 17).
- The rules for a **child's means in controlled work** (a parent's resources
  counting as the child's, regulation 16(4)), and the **other cases with no
  means test** in regulation 5 (care proceedings, mental health tribunals,
  inquests and others): the program knows only the child applicant's
  exception.
- **The full lists of disregarded payments** (regulations 24 and 40): the
  commonest are in the program's tables; any other kind of income or capital
  counts in full.
- **Subject matter of the dispute other than property**: only a property can
  be marked as what the dispute is about.

## The files

| File | What it is |
|---|---|
| `civil_legal_aid_means.le` | the program: the rules, the keycard figures, the caseworker's view, twelve example cases with their expected answers |
| `sources/financial_resources_regulations_2013.txt` | the regulations as in force from 22 July 2026, from legislation.gov.uk |
| `sources/si_2025_750.txt` | the Criminal and Civil Legal Aid (Amendment) Regulations 2025, which removed contributions |
| `sources/keycard_62.txt`, `sources/keycard_62_april_2026.pdf` | the Legal Aid Agency's eligibility keycard 62, April 2026 |
| `sources/lc_guidance_certificated_may_2025.txt` | the Lord Chancellor's guidance on determining financial eligibility for certificated work, May 2025 |
| `sources/lc_guidance_controlled_may_2025.txt` | the Lord Chancellor's guidance for controlled work and family mediation, May 2025 |
| `sources/means_assessment_guidance_august_2026_extract.txt` | the Legal Aid Agency's Means Assessment Guidance, August 2026: version history and Appendices 1, 11 and 15 |

The sources were published at:

- <https://www.legislation.gov.uk/uksi/2013/480> and <https://www.legislation.gov.uk/uksi/2025/750/made>
- <https://www.gov.uk/guidance/civil-legal-aid-means-testing>, which links the keycard, the two guidance documents and the Means Assessment Guidance.

## Licence and disclaimer

Contains public sector information licensed under the
[Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
The program is an adaptation of that information. It is not published or
endorsed by the Legal Aid Agency or the Ministry of Justice. It is provided
"as is", without warranty of any kind, and is not legal advice: check it
against the regulations and the guidance before relying on it.
