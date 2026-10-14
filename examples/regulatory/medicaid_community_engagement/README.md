# The Medicaid community engagement requirement, in Logical English

*Kind: example · Audience: readers of rules for public services · Status: written 14 October 2026*

From 1 January 2027, many adults who get Medicaid in the United States must
show, as a condition of keeping it, that they work, study, volunteer or earn
enough each month. The law calls this the **community engagement
requirement**; it is often called the "work requirement". The law is section
71119 of Public Law 119-21, the budget law of July 2025. It adds a new
subsection, 1902(xx), to the Social Security Act. On 1 June 2026 the
Centers for Medicare & Medicaid Services (CMS), the federal agency that runs
Medicaid, issued an **interim final rule**: a regulation that takes effect at
once and is still open to public comment. The rule says how every State must
apply the requirement. It adds sections 435.550 to 435.563 to title 42 of
the Code of Federal Regulations (written "42 CFR").

This folder holds the parts of that rule that decide a person's case,
written in **Logical English**: rules in English that a computer runs, giving
the reasons for every answer. Each rule names the paragraph of 42 CFR it
comes from, and the subsection of the law behind it.

## Try it

- Open [medicaid_community_engagement.le](medicaid_community_engagement.le?scenario=renewal_short&query=decision) and press **Query**. Fay's renewal is due in July 2027. Her State asks for 2 of the months from January to June. She worked 80 hours only in March, and earned $400 a month, less than $580. The answer is *unable to verify: notice of noncompliance, 30 days to show compliance*. Click the answer: each step names its paragraph of the rule.
- Choose the scenario **seasonal_worker** and run the query **reasons**. Eli and Fin earned the same. Eli is a seasonal worker, so his income is averaged over the 6 months before: $700 a month, enough. Fin is not, and falls short.
- Choose **age_pregnancy_and_release** and run **reasons**. Leo was in jail in January 2027. January counts for him because he was an inmate that month. February and March count because he was one in the 3 months before. Teo turned 19 in March, so each of the three months counts for him because he was under 19 for all or part of it.
- Choose **hardship** and run **decision**. Quinn and Rae were both in hospital in February, but only Rae asked for the short-term hardship exception. The rule says a hospital stay counts only on request, so Quinn gets a notice and Rae does not.

The queries are `decision` (the outcome for each person), `applicable` (who
is subject to the requirement), `exempt` (who is excluded, and why), `meets`
and `reasons` (the months that count, and why), and `short` (the months that
do not count).

The program also has a view, *caseworker desk*: a screen that a caseworker
could use. Open it in the executive view. It shows a person's facts in groups
(the decision, the State's choices, the work and income of each month, the
exclusions, the hardships). It shows the decision with its reasons and the
passages of the rule they rest on. It lists the exclusion found, the months
met and the months not met. Its *What would change the decision* button
finds the smallest changes to the facts that would change the outcome. For
Fay, for example, it finds that one more month in which she was pregnant, in
jail or in drug treatment would be enough. It does not propose more hours or
more income, because it never invents a number.

## What the program is

- **The facts** are those of one case. A **scenario** states them: whom the
  case is about, the month of the application or of the renewal, the
  person's date of birth and eligibility group, and, month by month, the
  hours of work, of community service, of a work program and of study, and
  the income. It also states the facts behind each exclusion: a pregnancy, a
  child in the person's care, a stay in jail, and so on.
- **The State's choices** are facts of the scenario too. The rule leaves
  several matters to each State: how many months it checks before an
  application (1 to 3) and at a renewal, whether it turns income into hours
  of work, whether it offers the short-term hardship exception, its list of
  conditions for medical frailty, a minimum time in drug or alcohol
  treatment, an earlier start, or a delay that CMS has granted.
- **The rules** are those of sections 435.551 to 435.556 and 435.559: who
  is an *applicable individual*, meaning a person to whom the requirement
  applies (435.551); the seven ways to meet it in a month (435.552); the
  months in which a person counts as meeting it anyway (435.553); the ten
  kinds of *specified excluded individual*, meaning a person to whom the
  requirement never applies (435.554); the optional short-term hardship
  exception (435.555); the months a State checks at an application and at a
  renewal (435.556); and the date from which the requirement applies
  (435.559, with the delay of 435.560). 82 rules; the 65 that encode a
  paragraph name it.
- **A month** is written as the date of its first day: 2027-03-01 is March
  2027.
- The date arithmetic (ages, months before and after) is the shared library
  `temporal.le`, copied beside the program.

## How it was made, and how it was checked

The program was **written by hand, with an AI agent, from the published
rule**: the regulation text at the end of Federal Register document
2026-11094, read together with the explanation that comes before it. It is
**not checked against any State's eligibility system**.

The program has 12 scenarios and 34 people. Each scenario expects answers to
the six queries, 72 expectations in all. **The expected answers were worked
out by hand from the text of the rule before the program was run.** For each
person, the agent wrote down which months the State checks, what the person
did in each month, which paragraph of the rule applies, and the outcome. For
example: 435.556(a)(1) gives February and March 2027 for an application in
April when the State checks 2 months. The person worked 40 hours, gave 25
hours of community service and studied 2 credit hours less than half-time,
which 435.552(d) counts as 2 × 3 × 4.33 = 25.98 hours. That makes 90.98
hours in all, at least 80, so 435.552(e) is met. Only then was the program
run, and its answers compared with those worked out by hand. They agreed on
all 72. To check that the tests would catch a mistake, one of Eli's
incomes was changed by hand; four expectations then failed, as they should.

Two mistakes were found and corrected while the program was being written,
before any expected answer was recorded. First, a person who worked 80 hours
was also given "80 hours of activities combined" as a reason, because of
the way a condition joining *and* and *or* on one line was read; the rule is
now written as separate rules. Second, the verifier pointed out that this
rule asked about itself through a negation; it now asks about the hours
directly.

The hand working and the program were done by the same agent, so where both
read a passage the same way, the agreement does not prove that reading
right. The places where the text had to be read with a choice are listed
below. A second, independent reading would be the next check.

## Where the text had to be read with a choice

- **"For part or all of the month."** An exception applies if the person was
  under 19 for part of the month, or the child in their care was 13 or under.
  Ages are taken on the first day of the month, so a person who turns 19
  during a month was under 19 for part of it.
- **"The preceding 6 months"** of a seasonal worker are the six months before
  the month being checked, not including it. A month with no income stated
  counts as no income.
- **Released from an institution "at any point during the 3-month period
  ending on the first day of that month"** (435.553(b)) is read as an inmate in
  any of the three calendar months before.
- **Medically frail** (435.554(c)(5)). A person counts if a condition
  significantly impairs their ability to meet the requirement *and* they fall
  in one of the five groups (A) to (E). A person also counts if their
  diagnosis is on the State's list, which the rule says identifies those
  people.
- **A SNAP household** (435.554(c)(7)). The person is excluded if their
  household receives SNAP (food assistance) and they are not exempt from
  SNAP's own work requirement. Unlike the TANF exclusion (cash assistance,
  435.554(c)(6)), the text does not ask whether the person actually meets
  that requirement, and the program follows the text.
- **Income turned into hours** (435.552(e)(2)). The rule tells the State to
  share a household's income among its members "by a reasonable method". The
  program takes the monthly income given as the person's own share.
- **A combination of activities** is given as the reason for a month only
  where no single activity reaches 80 hours alone, so that the reasons name
  what was decisive.
- **The start date.** It is 1 January 2027, or the State's earlier date, or,
  where CMS has granted a delay (a "good faith exemption"), the day after the
  delay ends, and never later than 1 January 2029.
- **Whether a person is an applicable individual** is decided in the month of
  the application or of the renewal.

## What is covered, and what is left out

Covered: the definitions and decisions of 435.551 to 435.556, 435.559 and the
end date of 435.560(c), with every mandatory exception and exclusion and the
four short-term hardship events.

Left out:

- **How a State checks the facts** (435.557): the data sources, the
  documents it may ask for, and the rules for checking medical frailty. Here
  the facts are simply given.
- **Notices and outreach** (435.558, 435.561), beyond the result that a
  person who has not shown the requirement is sent a notice of noncompliance.
  The 30 days to answer, and the State's duty to consider every other way of
  qualifying for Medicaid before refusing it, are not modelled.
- **Reporting to CMS** (435.562) and the ban on waivers (435.563).
- **More frequent checks between renewals** (435.556(a)(2)(ii)) and checks
  after a change in circumstances (435.556(a)(2)(iii)).
- **What counts as work, community service, a work program or an educational
  program** (435.552(b)), and the school's own rules on enrolment status
  (435.552(c)). The hours stated in a scenario are taken to be qualifying
  hours.
- **The details behind some facts**: the relationships that make a
  *caretaker relative* (including those a State may add), who counts as an
  Indian under 42 CFR 447.51, the mandatory coverage groups of section
  1902(a)(10)(A)(i), and how long a disaster exception lasts. Each is one fact
  of the scenario.
- The minimum wage is the federal one of 2026, $7.25 an hour. A change to it
  is a change to the constant at the top of the program.

## The files

| File | What it is |
|---|---|
| `medicaid_community_engagement.le` | the program: the rules, the caseworker's view, and 12 scenarios with their expected answers |
| `temporal.le`, `temporal.pl` | the shared date library (`lib/temporal`), copied here |

## Source and disclaimer

Centers for Medicare & Medicaid Services, "Medicaid Program; Community
Engagement Requirement for Certain Individuals", interim final rule with
comment period, 91 FR 33348, 3 June 2026, document 2026-11094:
<https://www.federalregister.gov/documents/2026/06/03/2026-11094/medicaid-program-community-engagement-requirement-for-certain-individuals>.
The correction of 29 June 2026 (C1-2026-11094) reprints sections 435.557 and
435.558 and changes nothing encoded here.

The rule and the law are works of the United States federal government. They
are in the public domain (17 U.S.C. 105). This program is not published or
endorsed by CMS or any State. It is provided "as is", without warranty of any
kind, and is not legal advice. Check it against the rule before relying on
it.
