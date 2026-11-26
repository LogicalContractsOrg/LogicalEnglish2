/** <module> Agent-written scenarios for the specification's examples and the door's own cases

    case(Stem, Scenarios, Queries)
        Stem       the file name of the description without `.ttl`
        Scenarios  [scenario(Name, Facts, Expectations)]: Facts are IR
                   literals of lib/lomo.le (`lomo_happens_on(Event, Date)`,
                   `lomo_calendar_starts(Date)`, ...); Expectations are
                   expects(Query, Answers), the answers as sentences.
        Queries    [query(Name, Body)]: queries this register needs beside
                   the questions every register has.

    The expected answers were worked out by the agent (Opus 5.5) from the specification's
    text and the dates of each case, before the registers were run: they are
    the test, not a record of what the library answers. The arithmetic is
    the calendar's: a month after 31 January is 28 or 29 February, hours are
    whole days rounded up.

    Copyright Miguel Calejo; Apache License 2.0.
*/

:- module(spec_cases, [case/3, case/4]).

%   case(Stem, Scenarios, Queries, Templates): Templates are the templates
%   a case's own sentences need (template(F, Text)), declared in its register.
case(Stem, Ss, Qs, []) :- case(Stem, Ss, Qs).
case(Stem, Ss, Qs, Ts) :- case_t(Stem, Ss, Qs, Ts).

:- discontiguous case/3, case_t/4.

%   ---- step 3: time -----------------------------------------------------

%  "Before 3 years after the approval date": P3Y immediately after the event.
case(duration,
     [ scenario(approved_on_15_may_2026,
                [lomo_happens_on("the approval date", date(2026, 5, 15))],
                [ expects(first_dates, ["the first date of approval date is 2026-05-15",
                                        "the first date of item a 1 time is 2029-05-15"]) ]) ],
     []).

%  72 hours after a personal data breach: 3 days. The second example writes
%  24 hours as "P24H", which is not ISO 8601 (PT24H): no date.
case('TemporalSpecification',
     [ scenario(breach_on_1_march_2026,
                [lomo_happens_on("personal data breach", date(2026, 3, 1)),
                 lomo_happens_on("completion of the landing", date(2026, 3, 1))],
                [ expects(first_dates, ["the first date of breach event is 2026-03-01",
                                        "the first date of deadline breach notification is 2026-03-04",
                                        "the first date of completion of landing is 2026-03-01"]),
                  expects(hours_as_days, ["deadline breach notification has a length of time that counts hours as whole days"]) ]) ],
     []).

%  An instant as a date, as a date and a time (its day), and as a month
%  with no year (no date).
case(instant,
     [ scenario(the_instants, [],
                [ expects(first_dates, ["the first date of r 1 action time is 2026-04-12",
                                        "the first date of action meeting time is 2026-04-12"]),
                  expects(last_dates, ["the last date of r 1 action time is 2026-04-12",
                                       "the last date of action meeting time is 2026-04-12"]) ]) ],
     []).

%  "Every year until 2035": from a calendar that starts on 30 June 2030,
%  the five dates up to the end of 2035.
case(frequency,
     [ scenario(from_30_june_2030,
                [lomo_calendar_starts(date(2030, 6, 30))],
                [ expects(falls_2030_to_2040, ["item a 1 time falls on 2031-06-30 in the period from 2030-01-01 to 2040-12-31",
                                               "item a 1 time falls on 2032-06-30 in the period from 2030-01-01 to 2040-12-31",
                                               "item a 1 time falls on 2033-06-30 in the period from 2030-01-01 to 2040-12-31",
                                               "item a 1 time falls on 2034-06-30 in the period from 2030-01-01 to 2040-12-31",
                                               "item a 1 time falls on 2035-06-30 in the period from 2030-01-01 to 2040-12-31"]),
                  expects(first_dates, ["the first date of item a 1 time end time is 2035-01-01"]),
                  expects(last_dates, ["the last date of item a 1 time end time is 2035-12-31"]) ]) ],
     [ query(falls_2030_to_2040, lomo_falls_on(_, _, date(2030, 1, 1), date(2040, 12, 31))) ]).

%  "Every year during 5 years": five dates from 2027-01-01.
case(repetitions,
     [ scenario(from_1_january_2027,
                [lomo_calendar_starts(date(2027, 1, 1))],
                [ expects(falls_2027_to_2040, ["item a 1 time falls on 2028-01-01 in the period from 2027-01-01 to 2040-12-31",
                                               "item a 1 time falls on 2029-01-01 in the period from 2027-01-01 to 2040-12-31",
                                               "item a 1 time falls on 2030-01-01 in the period from 2027-01-01 to 2040-12-31",
                                               "item a 1 time falls on 2031-01-01 in the period from 2027-01-01 to 2040-12-31",
                                               "item a 1 time falls on 2032-01-01 in the period from 2027-01-01 to 2040-12-31"]) ]) ],
     [ query(falls_2027_to_2040, lomo_falls_on(_, _, date(2027, 1, 1), date(2040, 12, 31))) ]).

%  The fiscal year starts the reporting period, both on 1 January 2025: no
%  conflict. The second example links a time to an action (LOMO's range is
%  a temporal specification): kept, and it has no date.
case(starts,
     [ scenario(the_links, [],
                [ expects(times_within, ["fiscal year 2025 is during reporting period 2025",
                                         "action review report time is during action submit report"]),
                  expects(broken_links, []) ]) ],
     []).

case(finishedBy,
     [ scenario(the_links, [],
                [ expects(times_within, ["fiscal year 2025 is during deadline submit report",
                                         "action review report is during action submit report time"]),
                  expects(broken_links, []) ]) ],
     []).

%  Two periods of three months, a month apart, overlap: no conflict. The
%  first example links two names (temporal spec project a, b) that the
%  description gives no times: the actions' own times are blank nodes.
case(overlaps,
     [ scenario(the_periods, [],
                [ expects(first_dates, ["the first date of action project a time is 2025-01-01",
                                        "the first date of action project b time is 2025-03-01",
                                        "the first date of temporal spec event a is 2025-01-01",
                                        "the first date of temporal spec event b is 2025-02-01"]),
                  expects(last_dates, ["the last date of action project a time is 2025-07-01",
                                       "the last date of action project b time is 2025-09-01",
                                       "the last date of temporal spec event a is 2025-04-01",
                                       "the last date of temporal spec event b is 2025-05-01"]),
                  expects(broken_links, []) ]) ],
     []).

case(hasFunction,
     [ scenario(the_functions, [],
                [ expects(deadlines, ["action submit report has action submit report time as deadline"]),
                  expects(first_dates, ["the first date of action submit report time is 2025-12-31"]) ]) ],
     []).

%  The door's own case: two links that the dates contradict, one that holds.
case(time_conflicts,
     [ scenario(the_conflicts, [],
                [ expects(broken_links, ["appeal breaks its link with notification",
                                         "meeting breaks its link with window"]) ]) ],
     []).

%   ---- step 4: who is bound, derogation, the conditions of a rule --------

%  The probe of the research note (LOMO.md §3.3), from a register the reader
%  wrote: who must do what by when, the derogation, who is late.
case(probe,
     [ scenario(case_one,
                [lomo_of_type(acme, controllers), lomo_of_type(acme, undertakings),
                 lomo_of_type(tiny, undertakings), lomo_of_type(tiny, 'micro undertakings'),
                 lomo_happens_to("awareness of a personal data breach", acme, date(2026, 3, 1)),
                 lomo_performs_on(acme, 'notify the breach', date(2026, 3, 5)),
                 lomo_happens_to("balance sheet date", acme, date(2025, 12, 31)),
                 lomo_happens_to("balance sheet date", tiny, date(2025, 12, 31))],
                [ expects(applies, ["norm gdpr 33 applies to acme", "norm accounts 30 applies to acme",
                                    "norm micro 36 applies to tiny"]),
                  expects(set_aside, ["norm accounts 30 is set aside for tiny by norm micro 36"]),
                  expects(must_perform, ["acme must perform notify the breach by 2026-03-04 under norm gdpr 33",
                                         "acme must perform publish the statements by 2026-12-31 under norm accounts 30"]),
                  expects(late_on_1_april_2026, ["acme is late with notify the breach under norm gdpr 33 on 2026-04-01"]),
                  expects(permitted, ["tiny is permitted that tiny performs skip the publication"]),
                  expects(violations, ["the obligation of acme that acme performs publish the statements is violated"]),
                  expects(rules_without_conditions, ["norm gdpr 33 has no written conditions",
                                                     "norm accounts 30 has no written conditions",
                                                     "norm micro 36 has no written conditions"]) ]),
       scenario(to_the_minute,
                [lomo_of_type(acme, controllers), lomo_of_type(beta, controllers),
                 lomo_happens_at("awareness of a personal data breach", acme, "2026-03-01T14:30"),
                 lomo_performs_at(acme, 'notify the breach', "2026-03-04T10:00"),
                 lomo_happens_at("awareness of a personal data breach", beta, "2026-03-01T14:30"),
                 lomo_performs_at(beta, 'notify the breach', "2026-03-04T16:00")],
                [ expects(must_perform_by_the_moment, ["acme must perform notify the breach by the moment 2026-03-04T14:30 under norm gdpr 33",
                                                       "beta must perform notify the breach by the moment 2026-03-04T14:30 under norm gdpr 33"]),
                  expects(met_in_time, ["acme met notify the breach in time under norm gdpr 33"]),
                  expects(late_at_midnight_4_march, ["beta is late with notify the breach under norm gdpr 33 at 2026-03-05T00:00"]) ]) ],
     [ query(late_on_1_april_2026, lomo_late(_, _, _, date(2026, 4, 1))),
       query(late_at_midnight_4_march, lomo_late_at(_, _, _, "2026-03-05T00:00")) ]).

%  The specification's three examples of derogatesFrom. The rules of the
%  examples are abbreviated (the specification says so: no actions), so each
%  scenario adds the action and its bearer, as a full description would have
%  them, and a case; the second and third write the derogating rule's
%  conditions, as the condition slot of lib/lomo.le allows.
case_t(derogatesFrom,
     [ scenario(micro_entities,
                [ lomo_produces('norm dir 2013 34 art 1 general obligation', 'prepare the statements'),
                  lomo_agent_role_of('prepare the statements', 'role preparer'),
                  lomo_for_agent('role preparer', undertakings), lomo_with_role('role preparer', addresser),
                  lomo_produces('norm dir 2013 34 art 1 a micro entity', 'use the micro regime'),
                  lomo_agent_role_of('use the micro regime', 'role micro'),
                  lomo_for_agent('role micro', 'micro entities'), lomo_with_role('role micro', addresser),
                  lomo_of_type(acme, undertakings),
                  lomo_of_type(tiny, undertakings), lomo_of_type(tiny, 'micro entities') ],
                [ expects(applies, ["norm dir 2013 34 art 1 general obligation applies to acme",
                                    "norm dir 2013 34 art 1 a micro entity applies to tiny"]),
                  expects(set_aside, ["norm dir 2013 34 art 1 general obligation is set aside for tiny by norm dir 2013 34 art 1 a micro entity"]),
                  expects(obliged, ["acme is obliged that acme performs prepare the statements"]) ]),
       scenario(consent_or_contract,
                [ lomo_produces('norm gdpr art 6 1 a consent', 'process personal data'),
                  lomo_produces('norm gdpr art 6 1 b contract performance', 'process personal data'),
                  lomo_agent_role_of('process personal data', 'role controller'),
                  lomo_for_agent('role controller', controllers), lomo_with_role('role controller', addresser),
                  lomo_written_conditions('norm gdpr art 6 1 b contract performance'),
                  rule(lomo_conditions_hold('norm gdpr art 6 1 b contract performance', P),
                       and(lomo_counts_as(P, controllers), case_contract_needs(P))),
                  lomo_of_type(shop, controllers), case_contract_needs(shop),
                  lomo_of_type(club, controllers) ],
                [ expects(applies, ["norm gdpr art 6 1 a consent applies to club",
                                    "norm gdpr art 6 1 b contract performance applies to shop"]),
                  expects(set_aside, ["norm gdpr art 6 1 a consent is set aside for shop by norm gdpr art 6 1 b contract performance"]),
                  expects(rules_without_conditions, ["norm dir 2013 34 art 1 general obligation has no written conditions",
                                                     "norm dir 2013 34 art 1 a micro entity has no written conditions",
                                                     "norm gdpr art 6 1 a consent has no written conditions",
                                                     "norm eu 2019 1242 art 4 co 2 monitoring has no written conditions",
                                                     "norm eu 2019 1242 art 5 4 vehicle derogation has no written conditions"]) ]),
       scenario(exempt_vehicles,
                [ lomo_produces('norm eu 2019 1242 art 4 co 2 monitoring', 'monitor the emissions'),
                  lomo_produces('norm eu 2019 1242 art 5 4 vehicle derogation', 'leave the vehicles unmonitored'),
                  lomo_agent_role_of('monitor the emissions', 'role monitor'),
                  lomo_agent_role_of('leave the vehicles unmonitored', 'role monitor'),
                  lomo_for_agent('role monitor', manufacturers), lomo_with_role('role monitor', addresser),
                  lomo_written_conditions('norm eu 2019 1242 art 5 4 vehicle derogation'),
                  rule(lomo_conditions_hold('norm eu 2019 1242 art 5 4 vehicle derogation', P),
                       and(lomo_counts_as(P, manufacturers), case_exempt_vehicles(P))),
                  lomo_of_type(truckco, manufacturers),
                  lomo_of_type(busco, manufacturers), case_exempt_vehicles(busco) ],
                [ expects(applies, ["norm eu 2019 1242 art 4 co 2 monitoring applies to truckco",
                                    "norm eu 2019 1242 art 5 4 vehicle derogation applies to busco"]),
                  expects(obliged, ["truckco is obliged that truckco performs monitor the emissions"]),
                  expects(permitted, ["busco is permitted that busco performs leave the vehicles unmonitored"]) ]) ],
     [],
     [ template(case_contract_needs, "*a party* processes personal data that a contract needs"),
       template(case_exempt_vehicles, "*a party* makes only vehicles of the exempt categories") ]).

%  Directive 2013/34/EU, Article 30(1): publish within 12 months after the
%  balance sheet date. Two undertakings close their accounts on
%  31 December 2025; bigco publishes on 30 November 2026, smallco never.
%  On 1 February 2027, bigco has met the duty and smallco is late.
case('financial-reporting-dir_2013_34-lomo-manual',
     [ scenario(reporting_2027,
                [lomo_of_type(bigco, 'actor large undertaking'), lomo_of_type(smallco, 'actor small undertaking'),
                 lomo_happens_to("balance sheet date", bigco, date(2025, 12, 31)),
                 lomo_happens_to("balance sheet date", smallco, date(2025, 12, 31)),
                 lomo_performs_on(bigco, 'step publish full report', date(2026, 11, 30))],
                [ expects(must_perform, ["bigco must perform step publish full report by 2026-12-31 under norm publication obligation",
                                         "smallco must perform step publish full report by 2026-12-31 under norm publication obligation"]),
                  expects(late_on_1_february_2027, ["smallco is late with step publish full report under norm publication obligation on 2027-02-01"]) ]) ],
     [ query(late_on_1_february_2027, lomo_late(_, _, _, date(2027, 2, 1))) ]).

%  A repeating duty (agent-written description, corpus/cases/annual_report.ttl):
%  three yearly reports after the start of operation, 15 January 2025. Due on
%  15 January 2026, 2027 and 2028. The report of 10 January 2026 meets the
%  first; none comes for the second; the report of 1 February 2027 is after
%  the second was due, so it meets the third. On 30 June 2027: the first met,
%  the second breached, the third met.
case(annual_report,
     [ scenario(three_reports,
                [lomo_of_type(acme, operators),
                 lomo_happens_to("start of operation", acme, date(2025, 1, 15)),
                 lomo_performs_on(acme, 'submit the report', date(2026, 1, 10)),
                 lomo_performs_on(acme, 'submit the report', date(2027, 2, 1))],
                [ expects(occurrences_on_30_june_2027,
                          ["the occurrence 1 of submit the report under norm annual report for acme is due on 2026-01-15 as of 2027-06-30",
                           "the occurrence 2 of submit the report under norm annual report for acme is due on 2027-01-15 as of 2027-06-30",
                           "the occurrence 3 of submit the report under norm annual report for acme is due on 2028-01-15 as of 2027-06-30"]),
                  expects(met_on_30_june_2027,
                          ["acme met the occurrence 1 of submit the report under norm annual report as of 2027-06-30",
                           "acme met the occurrence 3 of submit the report under norm annual report as of 2027-06-30"]),
                  expects(breached_on_30_june_2027,
                          ["acme breached the occurrence 2 of submit the report under norm annual report as of 2027-06-30"]),
                  expects(owed_on_30_june_2027, []) ]) ],
     [ query(occurrences_on_30_june_2027, lomo_occurrence_due(_, _, _, _, _, date(2027, 6, 30))),
       query(met_on_30_june_2027, lomo_occ_met(_, _, _, _, date(2027, 6, 30))),
       query(breached_on_30_june_2027, lomo_occ_breached(_, _, _, _, date(2027, 6, 30))),
       query(owed_on_30_june_2027, lomo_occ_owes(_, _, _, _, date(2027, 6, 30))) ]).
