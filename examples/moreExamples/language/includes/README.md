# Including other programs and Prolog resources

- `citizenship_including.le` — a program including another LE program
  (`citizenship_premier.le`, beside it) and one by URL.
- `prolog_resources/` — a thin LE layer over a Prolog facts file (§14.1).
- `scenarios/` — scenarios in a file of their own: `fee.le` gets the rules of
  `fee_rules.le` and the scenarios of `fee_cases.le` (`includes these
  scenarios:`, §14.3).
- `facts_background/` — a rule base with a facts background (`the facts
  background includes these resources:`, §14.5): `shirts.le` names
  `background/garment_words.le` (what the words of a listing mean) and
  `background/garment_presumptions.le` (what is taken to be so when a
  listing is silent). Only "Write it in English" uses the background.
