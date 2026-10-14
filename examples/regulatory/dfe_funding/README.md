# The Department for Education's 16 to 19 funding rules, in Logical English

*Kind: example · Audience: readers of rules for public services · Status: written 13 October 2026*

England's Department for Education calculates the funding of each student aged
16 to 19 with a rulebase built in Oracle Intelligent Advisor (formerly Oracle
Policy Automation). Each year it publishes the rules of that rulebase, as they
are written in the rulebase's Word documents, in a technical specification.
This folder holds **all of those rules** for 2026 to 2027 (section 4 of the
specification, pages 37 to 89) written in **Logical English**: rules in English
that a computer runs, giving the reasons for every answer.

## Try it

- Open [dfe_16_19_funding.le](dfe_16_19_funding.le?scenario=full_time&query=OnProgPayment) and press **Query**. The answer is *the on programme funding of learner sp01 is 6152.36996634624*: the national rate of £5,256 for a full-time student, times the provider's retention factor, programme weighting, uplifts and area cost factor (page 38).
- Click the answer. Each step names the rule and the page of the specification it comes from, down to the student's courses.
- Choose the scenario **t_level_short_of_band_9** and run the query **RateBand**: a T level student in funding band 9 with only 1,400 planned hours falls to band 7, because the rows of the table on page 50 are tried in order.
- Choose **early_leaver** and run **StartFund**: there is no answer. The student left before the qualifying period (page 70), so does not count as a start and earns no funding.
- Choose **condition_of_funding** and run **ConditionOfFundingEnglish**: *Doesn't have English, Studying English*, for a student with grade 3 in English who is studying GCSE English for the minimum hours (pages 41 to 45).

The queries are named after the outputs of the specification's interface
agreement (pages 34 to 36): `OnProgPayment`, `RateBand`, `NatRate`, `FundLine`,
`StartFund`, `ConditionOfFundingEnglish`, and the others.

## What the program is

- **The data** are the records of the interface agreement (pages 20 to 36):
  the provider and its factors, the postcode specialist resource reference
  data, the student, the student's courses (called *learning deliveries*), and
  each course's funding and monitoring codes, its records in the Learning Aim
  Reference Service (LARS), and its hours records. A scenario states them as
  facts.
- **The rules** are every element of section 4: source of funding and funding
  line, on-programme funding, the condition of funding for English and maths,
  the rate band and national rate, planned hours, the academic flag,
  retention, programme cost weighting (with the A level uplift and the
  specialist-resource postcodes), disadvantage, English and maths instances,
  the date rules, core aim selection, and the T level rules (programme aims,
  transition programmes, occupational specialisms, funding bands and
  weightings). 160 rules, each naming its page.
- A rule table of the rulebase, whose rows are tried from the top, is written
  as an `otherwise` cascade, with its rows in the same order.
- Two small text operations of the rulebase, ToUpper() and "contains", are in
  `dfe_text.pl`. The date arithmetic (ages, whole months) is the shared library
  `temporal.le`, copied beside the program as libraries are.

## How it was made, and how it was checked

The Department publishes the rules as a PDF, not as a project of Oracle's
Policy Modeling tool, and publishes no test cases with the rulebase's answers.
So this program was **not** made by our Oracle Intelligent Advisor translator,
and it is **not** checked against Oracle Intelligent Advisor. It was written by
hand, with an AI agent, from the printed pages.

It was checked in the only way open without Oracle's engine: **two independent
readings**. A second agent, which never saw this program, wrote the same rules
in Python from the same pages, with 96 test cases of its own designed to cover
every rule. Both were then run on those 96 cases and on 300 randomly generated
students, and compared on all 38 outputs:

| Cases | Outputs compared | Equal |
|---|---|---|
| 96 designed cases | 3,648 | 3,622 |
| 300 random students | 11,400 | 11,397 |

Every difference that came from reading a rule differently was settled against
the PDF, and the program corrected where it was wrong (once: a postcode record
whose effective date ends on 31 July still applies on 1 August, page 62).
**All the remaining differences are of one kind: what happens when a value the
rules need is missing.** Oracle's engine then leaves the conclusion "unknown"
(or "uncertain"), and the Python reading does the same. Logical English treats
a fact that is not stated as false, and goes on to the next row of the table.
That is the case for a student with no date of birth, no planned end date, no
hours record on a T level, or a course with no subject area, all of which the
real data must have. On every case where the student's record is complete, the
two readings agree on every output.

The test cases where they agree are kept, with their expected answers, in
`dfe_16_19_funding_tests.le` (92 cases, 920 expectations). The program's own
eight scenarios have 376 more. `check/README.md` says how to repeat the whole
comparison.

## Where a reading had to choose

The PDF is the rule documents as printed, and a few places had to be read with
a choice. Both readings made the same choices, independently:

- The rule "a recognised GCSE English qualification" (page 41) has no "or"
  between its first group and the next; the same rule for maths (page 42) has
  one. Both are read with "or".
- The ZTPR0012 row of the T level transition table (page 86) prints its last
  condition outside the "for at least one" above it; it is read as inside, like
  the rows before it.
- The count of postcode specialist resource records (page 62) tests only the
  dates, not the postcode, while the list next to it tests both. It is read as
  printed.
- The commentary of page 58 gives a weighting of 1.1 for science A levels and
  1.3 for the King's Trust TEAM programme; the rules give 1.15 and 1.44, which
  match the Department's published rates. The rules are followed.

The second reading's notes, `check/ref/NOTES.md`, list 26 such points.

## The files

| File | What it is |
|---|---|
| `dfe_16_19_funding.le` | the program: all the rules, with eight example students and their expected answers |
| `dfe_16_19_funding_tests.le` | 92 test students, with 920 expected answers, checked against the second reading |
| `dfe_text.pl` | ToUpper() and "contains", as two Prolog predicates |
| `temporal.le`, `temporal.pl` | the shared date library (`lib/temporal`), copied here |
| `16-to-19-funding-calculation-for-2026-to-2027-technical-specification-v1.00.pdf` | the specification, version 1.00, September 2026, as published at <https://www.gov.uk/government/publications/technical-specification-further-education-for-young-people> |
| `check/` | the second reading in Python, its test cases, and the tools that compare the two |

## Licence and disclaimer

Contains public sector information licensed under the
[Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
The program is an adaptation of that information. It is not published or
endorsed by the Department for Education. It is provided "as is", without
warranty of any kind, and is not advice: check it against the specification
before relying on it.
