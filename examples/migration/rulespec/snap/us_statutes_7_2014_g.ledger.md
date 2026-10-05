# Migration ledger: us_statutes_7_2014_g

Source: Axiom RuleSpec — sources/us/statutes/7/2014/g.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-05
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 27 |
| approximated | 0 |
| residue | 0 |
| **total** | 27 |

Fidelity: **12 of 12** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2014/g#snap_household_resource_limit_base_amount | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_household_resource_limit_base_amount |  |
| us:statutes/7/2014/g#snap_household_resource_limit_base_amount | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_household_resource_limit_base_amount |  |
| us:statutes/7/2014/g#snap_household_resource_limit_base_amount_with_elderly_or_disabled_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_household_resource_limit_base_amount_with_elderly_or_disabled_member |  |
| us:statutes/7/2014/g#snap_household_resource_limit_base_amount_with_elderly_or_disabled_member | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_household_resource_limit_base_amount_with_elderly_or_disabled_member |  |
| us:statutes/7/2014/g#allowable_financial_resources_rounding_increment | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_allowable_financial_resources_rounding_increment |  |
| us:statutes/7/2014/g#allowable_financial_resources_rounding_increment | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_allowable_financial_resources_rounding_increment |  |
| us:statutes/7/2014/g#statutory_household_resource_limit_base_amount | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_statutory_household_resource_limit_base_amount |  |
| us:statutes/7/2014/g#statutory_household_resource_limit_base_amount | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_statutory_household_resource_limit_base_amount |  |
| us:statutes/7/2014/g#next_annual_household_resource_limit_amount | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_next_annual_household_resource_limit_amount |  |
| us:statutes/7/2014/g#next_annual_household_resource_limit_amount | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_next_annual_household_resource_limit_amount |  |
| us:statutes/7/2014/g#licensed_vehicle_resource_fair_market_value_threshold | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_licensed_vehicle_resource_fair_market_value_threshold |  |
| us:statutes/7/2014/g#licensed_vehicle_resource_fair_market_value_threshold | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_licensed_vehicle_resource_fair_market_value_threshold |  |
| us:statutes/7/2014/g#vehicle_excluded_from_financial_resources_under_vehicle_exceptions | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_vehicle_excluded_from_financial_resources_under_vehicle_exceptions |  |
| us:statutes/7/2014/g#vehicle_excluded_from_financial_resources_under_vehicle_exceptions | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_vehicle_excluded_from_financial_resources_under_vehicle_exceptions |  |
| us:statutes/7/2014/g#licensed_vehicle_countable_resource_amount_under_default_rule | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_licensed_vehicle_countable_resource_amount_under_default_rule |  |
| us:statutes/7/2014/g#licensed_vehicle_countable_resource_amount_under_default_rule | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_licensed_vehicle_countable_resource_amount_under_default_rule |  |
| input household_includes_elderly_or_disabled_member | input | encoded | a name no rule defines -> a fact the scenario states | rs_household_includes_elderly_or_disabled_member |  |
| input prior_unrounded_household_resource_limit_amount | input | encoded | a name no rule defines -> a fact the scenario states | rs_prior_unrounded_household_resource_limit_amount |  |
| input consumer_price_index_change_for_12_month_period_ending_preceding_june | input | encoded | a name no rule defines -> a fact the scenario states | rs_consumer_price_index_change_for_12_month_period_ending_preceding_june |  |
| input vehicle_used_to_produce_earned_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_vehicle_used_to_produce_earned_income |  |
| input vehicle_necessary_for_transport_of_physically_disabled_household_member | input | encoded | a name no rule defines -> a fact the scenario states | rs_vehicle_necessary_for_transport_of_physically_disabled_household_member |  |
| input vehicle_depended_on_to_carry_household_fuel_or_water | input | encoded | a name no rule defines -> a fact the scenario states | rs_vehicle_depended_on_to_carry_household_fuel_or_water |  |
| input vehicle_provides_household_primary_source_of_fuel_or_water | input | encoded | a name no rule defines -> a fact the scenario states | rs_vehicle_provides_household_primary_source_of_fuel_or_water |  |
| input asset_is_licensed_vehicle | input | encoded | a name no rule defines -> a fact the scenario states | rs_asset_is_licensed_vehicle |  |
| input asset_is_used_for_household_transportation_or_to_obtain_or_continue_employment | input | encoded | a name no rule defines -> a fact the scenario states | rs_asset_is_used_for_household_transportation_or_to_obtain_or_continue_employment |  |
| input state_vehicle_allowance_standards_apply_in_lieu_of_default_vehicle_rule | input | encoded | a name no rule defines -> a fact the scenario states | rs_state_vehicle_allowance_standards_apply_in_lieu_of_default_vehicle_rule |  |
| input asset_fair_market_value | input | encoded | a name no rule defines -> a fact the scenario states | rs_asset_fair_market_value |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| household_resource_limit_with_elderly_member_and_annual_adjustment | q_allowable_financial_resources_rounding_increment | pass |  |
| household_resource_limit_with_elderly_member_and_annual_adjustment | q_next_annual_household_resource_limit_amount | pass |  |
| household_resource_limit_with_elderly_member_and_annual_adjustment | q_snap_household_resource_limit_base_amount | pass |  |
| household_resource_limit_with_elderly_member_and_annual_adjustment | q_snap_household_resource_limit_base_amount_with_elderly_or_disabled_member | pass |  |
| household_resource_limit_with_elderly_member_and_annual_adjustment | q_statutory_household_resource_limit_base_amount | pass |  |
| licensed_vehicle_default_countable_amount | q_licensed_vehicle_countable_resource_amount_under_default_rule | pass |  |
| licensed_vehicle_default_countable_amount | q_licensed_vehicle_resource_fair_market_value_threshold | pass |  |
| licensed_vehicle_default_countable_amount | q_vehicle_excluded_from_financial_resources_under_vehicle_exceptions | pass |  |
| licensed_vehicle_state_alternative_displaces_default_rule | q_licensed_vehicle_countable_resource_amount_under_default_rule | pass |  |
| licensed_vehicle_state_alternative_displaces_default_rule | q_vehicle_excluded_from_financial_resources_under_vehicle_exceptions | pass |  |
| licensed_vehicle_earned_income_use_exclusion | q_licensed_vehicle_countable_resource_amount_under_default_rule | pass |  |
| licensed_vehicle_earned_income_use_exclusion | q_vehicle_excluded_from_financial_resources_under_vehicle_exceptions | pass |  |

