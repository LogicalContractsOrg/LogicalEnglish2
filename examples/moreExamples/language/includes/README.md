# Including other programs and Prolog resources

- `citizenship_including.le` — a program including another LE program
  (`citizenship_premier.le`, beside it) and one by URL.
- `prolog_resources/` — a thin LE layer over a Prolog facts file (§14.1).
- `scenarios/` — scenarios in a file of their own: `fee.le` gets the rules of
  `fee_rules.le` and the scenarios of `fee_cases.le` (`includes these
  scenarios:`, §14.3).
