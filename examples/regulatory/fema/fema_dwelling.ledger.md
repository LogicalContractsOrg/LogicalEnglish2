# Migration ledger: fema_dwelling

Source: the wording — wording-fema_f-122-dwelling-sfip_2021.md
Translator: LE Contract Assistant (ledger_for.pl)
Date: 2026-10-25

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 77 |
| approximated | 18 |
| residue | 0 |
| skipped | 58 |
| not addressed | 59 |
| **total** | 212 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person. An element is **skipped** when it is not a rule (the note says why) and **not addressed** when it is a rule that nothing in the program encodes.

## Coverage of the wording

154 normative clause(s) (all but the 58 skipped): **77 encoded** (50%), 18 approximated (62% cited at some level), 59 not addressed.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| preamble preamble | cover_page | skipped |  |  | procedural (cover_page) |
| I AGREEMENT | insuring_agreement | skipped |  |  | a heading: its clauses are the units under it |
| I.A This policy insures the following types of property only: | insuring_agreement | skipped |  |  | a heading: its clauses are the units under it |
| I.A.1 A one to four family residential building, not under a condominium form of ownership; | insuring_agreement | not_addressed |  |  | no rule cites or quotes this clause |
| I.A.2 A single-family dwelling unit in a condominium building; _and | insuring_agreement | not_addressed |  |  | no rule cites or quotes this clause |
| I.A.3 Personal property in a building. | insuring_agreement | not_addressed |  |  | no rule cites or quotes this clause |
| I.B The Federal Emergency Management Agency (FEMA) provides flood insurance under the terms of… | insuring_agreement | not_addressed |  |  | no rule cites or quotes this clause |
| I.C We will pay you for direct physical loss by or from flood to your insured property if you: | insuring_agreement | encoded | a rule cites or quotes this clause | claim_covered, claim_qualification, component_covered, policy_conditions, zero_for_nonqualifying_component |  |
| I.C.1 Have paid the full amount due (including applicable premiums, surcharges, and fees); | insuring_agreement | approximated | a rule cites the enclosing or an enclosed clause | claim_covered, claim_qualification, component_covered, policy_conditions, zero_for_nonqualifying_component | covered at another level of the numbering: check that the rule carries this clause |
| I.C.2 Comply with all terms and conditions of this policy; _and | conditions | encoded | a rule cites or quotes this clause | policy_conditions |  |
| I.C.3 Have furnished accurate information and statements. | insuring_agreement | approximated | a rule cites the enclosing or an enclosed clause | claim_covered, claim_qualification, component_covered, policy_conditions, zero_for_nonqualifying_component | covered at another level of the numbering: check that the rule carries this clause |
| I.D We have the right to review the information you give us at any time and revise your policy… | insuring_agreement | not_addressed |  |  | no rule cites or quotes this clause |
| I.E This policy insures only one building. If you own more than one building, coverage will ap… | insuring_agreement | not_addressed |  |  | no rule cites or quotes this clause |
| I.F Subject to the exception in I.G below, multiple policies with building coverage cannot be … | insuring_agreement | encoded | a rule cites or quotes this clause | building_cover_purchased |  |
| I.G A Dwelling Form policy with building coverage may be issued to a unit owner in a condomini… | insuring_agreement | encoded | a rule cites or quotes this clause | coverage_exclusion_rcbap_duplicate |  |
| II DEFINITIONS | definitions | approximated | a rule cites the enclosing or an enclosed clause | calculated_acv, declarations_particulars, direct_physical_loss, flood_erosion, flood_mudflow, flood_surface_water, flood_two_acres, flood_two_properties, four_family_dwelling_helper, insurance_period, policy_in_force, scheduled_component_limit, single_family_dwelling_helper, three_family_dwelling_helper, two_family_dwelling_helper | covered at another level of the numbering: check that the rule carries this clause |
| II.B Flood, as used in this flood insurance policy, means: | definitions | skipped |  |  | a heading: its clauses are the units under it |
| II.B.1 A general and temporary condition of partial or complete inundation of two or more acres o… | definitions | encoded | a rule cites or quotes this clause | flood_surface_water, flood_two_acres, flood_two_properties |  |
| II.B.2 Collapse or subsidence of land along the shore of a lake or similar body of water as a res… | definitions | encoded | a rule cites or quotes this clause | flood_erosion |  |
| II.C The following are the other key definitions we use in this policy: | definitions | skipped |  |  | a heading: its clauses are the units under it |
| II.C.1 Act. The National Flood Insurance Act of 1968 and any amendments to it. | general_conditions | skipped |  |  | procedural (general_conditions) |
| II.C.2 Actual Cash Value. The cost to replace an insured item of property at the time of loss, le… | definitions | encoded | a rule cites or quotes this clause | calculated_acv |  |
| II.C.3 Application. The statement made and signed by you or your agent in applying for this polic… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.4 Base Flood. A flood having a one percent chance of being equaled or exceeded in any given … | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.5 Basement. Any area of a building, including any sunken room or sunken portion of a room, h… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.6 Building | definitions | encoded | a rule cites or quotes this clause | four_family_dwelling_helper, single_family_dwelling_helper, three_family_dwelling_helper, two_family_dwelling_helper |  |
| II.C.7 Cancellation. The ending of the insurance coverage provided by this policy before the expi… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.8 Condominium. That form of ownership of one or more buildings in which each unit owner has … | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.9 Condominium Association. The entity made up of the unit owners responsible for the mainten… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.10 Condominium Building. A type of building for which the form of ownership is one in which e… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.11 Declarations Page. A computer-generated summary of information you provided in your applic… | definitions | encoded | a rule cites or quotes this clause | declarations_particulars, insurance_period, policy_in_force, scheduled_component_limit |  |
| II.C.12 Deductible. The amount of an insured loss that is your responsibility and that is incurred… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.13 Described Location. The location where the insured building(s) or personal property are fo… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.14 Direct Physical Loss By or From Flood. Loss or damage to insured property, directly caused… | definitions | encoded | a rule cites or quotes this clause | direct_physical_loss |  |
| II.C.15 Dwelling. A building designed for use as a residence for no more than four families or a s… | definitions | encoded | a rule cites or quotes this clause | four_family_dwelling_helper, single_family_dwelling_helper, three_family_dwelling_helper, two_family_dwelling_helper |  |
| II.C.16 Elevated Building. A building that has no basement and that has its lowest elevated floor … | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.17 Emergency Program. The initial phase of a community’s participation in the National Flood … | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.18 Federal Policy Fee. A flat rate charge you must pay on each new or renewal policy to defra… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.19 Improvements. Fixtures, alterations, installations, or additions comprising a part of the … | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.20 Mudflow. A river of liquid and flowing mud on the surface of normally dry land areas, as w… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.21 National Flood Insurance Program (NFIP). The program of flood insurance coverage and flood… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.22 Policy. The entire written contract between you and us. It includes: | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.23 Pollutants. Substances that include, but are not limited to, any solid, liquid, gaseous, o… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.24 Post-FIRM Building. A building for which construction or substantial improvement occurred … | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.26 Probation Surcharge. A flat charge you must pay on each new or renewal policy issued cover… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.27 Regular Program. The final phase of a community’s participation in the National Flood Insu… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.28 Special Flood Hazard Area (SFHA). An area having special flood or mudflow, and/or flood-re… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.29 Unit. A single-family residential space you own in a condominium building. | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.30 Valued Policy. A policy in which the insured and the insurer agree on the value of the pro… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| II.C.25 Principal Residence. The dwelling in which you or your spouse have lived for at least 80 p… | definitions | not_addressed |  |  | no rule cites or quotes this clause |
| III PROPERTY INSURED | coverage | skipped |  |  | a heading: its clauses are the units under it |
| III.A Coverage A—Building Property | coverage | encoded | a rule cites or quotes this clause | building_cover_purchased, coverage_a_qualification |  |
| III.A.1 The dwelling at the described location, or for a period of 45 days at another location as … | coverage | approximated | a rule cites the enclosing or an enclosed clause | building_cover_purchased, coverage_a_qualification | covered at another level of the numbering: check that the rule carries this clause |
| III.A.3 A detached garage at the described location. Coverage is limited to no more than 10 percen… | coverage | encoded | a rule cites or quotes this clause | coverage_a_exclusion_detached_garage_use, detached_garage_amount |  |
| III.A.4 Materials and supplies to be used for construction, alteration, or repair of the dwelling … | coverage | approximated | a rule cites the enclosing or an enclosed clause | building_cover_purchased, coverage_a_qualification | covered at another level of the numbering: check that the rule carries this clause |
| III.A.5 A building under construction, alteration, or repair at the described location. | coverage | encoded | a rule cites or quotes this clause | construction_building_insured_property |  |
| III.A.6 A manufactured home or a travel trailer, as described in the II.C.6. If the manufactured h… | coverage | approximated | a rule cites the enclosing or an enclosed clause | building_cover_purchased, coverage_a_qualification | covered at another level of the numbering: check that the rule carries this clause |
| III.A.7 The following items of property which are insured under Coverage A only: | coverage | approximated | a rule cites the enclosing or an enclosed clause | building_cover_purchased, coverage_a_qualification | covered at another level of the numbering: check that the rule carries this clause |
| III.A.8 Items of property below the lowest elevated floor of an elevated postFIRM building located… | coverage | approximated | a rule cites the enclosing or an enclosed clause | building_cover_purchased, coverage_a_qualification | covered at another level of the numbering: check that the rule carries this clause |
| III.B Coverage B—Personal Property | coverage | skipped |  |  | a heading: its clauses are the units under it |
| III.B.1 If you have purchased personal property coverage, we insure against direct physical loss b… | coverage | encoded | a rule cites or quotes this clause | contents_cover_purchased, coverage_a_qualification, coverage_b_household_member, coverage_b_named_insured, coverage_b_named_tenant, coverage_b_tenant_condominium_unit |  |
| III.B.2 Personal property is also insured for a period of 45 days at another location as set forth… | coverage | not_addressed |  |  | no rule cites or quotes this clause |
| III.B.3 Personal property in a building that is not fully enclosed must be secured to prevent flot… | coverage | encoded | a rule cites or quotes this clause | coverage_b_exclusion_flotation |  |
| III.B.4 Coverage for personal property includes the following property, subject to B.1 above, whic… | coverage | not_addressed |  |  | no rule cites or quotes this clause |
| III.B.5 Coverage for items of property below the lowest elevated floor of an elevated post-FIRM bu… | coverage | not_addressed |  |  | no rule cites or quotes this clause |
| III.B.6 If you are a tenant and have insured personal property under Coverage B in this policy, we… | coverage | not_addressed |  |  | no rule cites or quotes this clause |
| III.B.8 Special Limits. We will pay no more than $2,500 for any one loss to one or more of the fol… | coverage | encoded | a rule cites or quotes this clause | contents_category_subtotal, ordinary_category_subtotal, special_category_cap |  |
| III.B.9 We will pay only for the functional value of antiques. | insuring_agreement | not_addressed |  |  | no rule cites or quotes this clause |
| III.B.1 Debris Removal | coverage | encoded | a rule cites or quotes this clause | contents_cover_purchased, coverage_b_household_member, coverage_b_named_insured, coverage_b_named_tenant, coverage_b_tenant_condominium_unit |  |
| III.B.2 Loss Avoidance Measures | coverage | encoded | a rule cites or quotes this clause | loss_avoidance_amount, loss_avoidance_civil_order, loss_avoidance_limit, loss_avoidance_nearby_flooding, loss_avoidance_qualification, no_deductible_loss_avoidance |  |
| III.B.3 Condominium Loss Assessments | coverage | encoded | a rule cites or quotes this clause | coverage_b_exclusion_flotation |  |
| III.D Coverage D—Increased Cost of Compliance | coverage | encoded | a rule cites or quotes this clause | no_deductible_coverage_d |  |
| III.D.1 General | coverage | not_addressed |  |  | no rule cites or quotes this clause |
| III.D.2 Limit of Liability | coverage | encoded | a rule cites or quotes this clause | building_cover_purchased, coverage_d_component_payment, coverage_d_limit, no_deductible_coverage_d |  |
| III.D.3 Eligibility | coverage | encoded | a rule cites or quotes this clause | building_cover_purchased, coverage_d_qualification, no_deductible_coverage_d, substantial_damage_percentage |  |
| III.D.4 Conditions | conditions | encoded | a rule cites or quotes this clause | building_cover_purchased, coverage_d_amount |  |
| III.D.5 Exclusions | exclusions | encoded | a rule cites or quotes this clause | coverage_d_exclusion_code_upgrade, coverage_d_exclusion_condominium_assessment, coverage_d_exclusion_emergency_program, coverage_d_exclusion_garage, coverage_d_exclusion_group_policy, coverage_d_exclusion_loss_in_value, coverage_d_exclusion_minimum_requirements, coverage_d_exclusion_pollutants, coverage_d_exclusion_post_loss_additions, coverage_d_exclusion_prior_requirement, coverage_d_exclusion_residual_value, coverage_d_exclusion_variance, no_deductible_coverage_d |  |
| III.D.6 Other Provisions | coverage | encoded | a rule cites or quotes this clause | no_deductible_coverage_d |  |
| IV PROPERTY NOT INSURED | property_not_covered | encoded | a rule cites or quotes this clause | zero_for_excluded_component |  |
| IV.1 Personal property not inside a building. | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_outside_building |  |
| IV.2 A building, and personal property in it, located entirely in, on, or over water or seaward… | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_over_water |  |
| IV.3 Open structures, including a building used as a boathouse or any structure or building int… | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_boathouse, property_exclusion_open_structure |  |
| IV.4 Recreational vehicles other than travel trailers described in the Definitions section (see… | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_recreational_vehicle |  |
| IV.5 Self-propelled vehicles or machines, including their parts and equipment. However, we do c… | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_self_propelled_vehicle |  |
| IV.6 Land, land values, lawns, trees, shrubs, plants, growing crops, or animals. | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_land |  |
| IV.7 Accounts, bills, coins, currency, deeds, evidences of debt, medals, money, scrip, stored v… | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_money |  |
| IV.8 Underground structures and equip ment, including wells, septic tanks, and septic systems. | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_underground |  |
| IV.9 Those portions of walks, walkways, decks, driveways, patios and other surfaces, all whethe… | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_exterior_surface |  |
| IV.10 Containers, including related equipment, such as, but not limited to, tanks containing gas… | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_container |  |
| IV.11 Buildings or units and all their contents if more than 49 percent of the actual cash value… | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_below_ground, property_exclusion_fence |  |
| IV.13 Aircraft or watercraft, or their furnishings and equipment. | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_aircraft_watercraft |  |
| IV.14 Hot tubs and spas that are not bathroom fixtures, and swimming pools, and their equipment,… | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_pool |  |
| IV.15 Property not eligible for flood insurance pursuant to the provisions of the Coastal Barrie… | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_coastal_barrier |  |
| IV.16 Personal property you own in common with other unit owners comprising the membership of a … | property_not_covered | encoded | a rule cites or quotes this clause | property_exclusion_common_condominium_property |  |
| V EXCLUSIONS | exclusions | skipped |  |  | a heading: its clauses are the units under it |
| V.A We only pay for direct physical loss by or from flood, which means that we do not pay you … | exclusions | approximated | a rule cites the enclosing or an enclosed clause | economic_exclusion_access, economic_exclusion_business_interruption, economic_exclusion_living_expenses, economic_exclusion_ordinance, economic_exclusion_other, economic_exclusion_revenue, economic_exclusion_use | covered at another level of the numbering: check that the rule carries this clause |
| V.A.1 Loss of revenue or profits; | exclusions | encoded | a rule cites or quotes this clause | economic_exclusion_revenue |  |
| V.A.2 Loss of access to the insured property or described location; | exclusions | encoded | a rule cites or quotes this clause | economic_exclusion_access |  |
| V.A.3 Loss of use of the insured property or described location; | exclusions | encoded | a rule cites or quotes this clause | economic_exclusion_use |  |
| V.A.4 Loss from interruption of business or production; | exclusions | encoded | a rule cites or quotes this clause | economic_exclusion_business_interruption |  |
| V.A.5 Any additional living expenses incurred while the insured building is being repaired or is… | exclusions | encoded | a rule cites or quotes this clause | economic_exclusion_living_expenses |  |
| V.A.6 The cost of complying with any ordinance or law requiring or | exclusions | encoded | a rule cites or quotes this clause | economic_exclusion_ordinance, no_deductible_coverage_d |  |
| V.A.7 Any other economic loss you suffer. | exclusions | encoded | a rule cites or quotes this clause | economic_exclusion_other |  |
| V.B Flood in Progress. If this policy became effective as of the time of a loan closing, as pr… | exclusions | encoded | a rule cites or quotes this clause | exclusion_flood_in_progress_application, exclusion_flood_in_progress_closing |  |
| V.C We do not insure for loss to property caused directly by earth movement even if the earth … | exclusions | encoded | a rule cites or quotes this clause | cause_exclusion_earth_movement |  |
| V.C.1 Earthquake; | exclusions | approximated | a rule cites the enclosing or an enclosed clause | cause_exclusion_earth_movement | covered at another level of the numbering: check that the rule carries this clause |
| V.C.2 Landslide; | exclusions | approximated | a rule cites the enclosing or an enclosed clause | cause_exclusion_earth_movement | covered at another level of the numbering: check that the rule carries this clause |
| V.C.3 Land subsidence; | exclusions | approximated | a rule cites the enclosing or an enclosed clause | cause_exclusion_earth_movement | covered at another level of the numbering: check that the rule carries this clause |
| V.C.4 Sinkholes; | exclusions | approximated | a rule cites the enclosing or an enclosed clause | cause_exclusion_earth_movement | covered at another level of the numbering: check that the rule carries this clause |
| V.C.5 Destabilization or movement of land that results from accumulation of water in subsurface … | exclusions | approximated | a rule cites the enclosing or an enclosed clause | cause_exclusion_earth_movement | covered at another level of the numbering: check that the rule carries this clause |
| V.C.6 Gradual erosion. | exclusions | approximated | a rule cites the enclosing or an enclosed clause | cause_exclusion_earth_movement | covered at another level of the numbering: check that the rule carries this clause |
| V.D We do not insure for direct physical loss caused directly or indirectly by any of the foll… | exclusions | approximated | a rule cites the enclosing or an enclosed clause | cause_exclusion_alteration, cause_exclusion_confined_moisture, cause_exclusion_conspiracy, cause_exclusion_controlled_moisture, cause_exclusion_deliberate_act, cause_exclusion_freezing, cause_exclusion_ice, cause_exclusion_rain, cause_exclusion_seepage, cause_exclusion_sewer_backup, cause_exclusion_sump, cause_exclusion_utility_failure, cause_exclusion_water_pressure, cause_exclusion_wind | covered at another level of the numbering: check that the rule carries this clause |
| V.D.1 The pressure or weight of ice; | exclusions | encoded | a rule cites or quotes this clause | cause_exclusion_ice |  |
| V.D.2 Freezing or thawing; | exclusions | encoded | a rule cites or quotes this clause | cause_exclusion_freezing |  |
| V.D.3 Rain, snow, sleet, hail, or water spray; | exclusions | encoded | a rule cites or quotes this clause | cause_exclusion_rain |  |
| V.D.4 Water, moisture, mildew, or mold damage that results primarily from any condition: | exclusions | encoded | a rule cites or quotes this clause | cause_exclusion_confined_moisture, cause_exclusion_controlled_moisture |  |
| V.D.5 Water or water-borne material that: | exclusions | encoded | a rule cites or quotes this clause | cause_exclusion_seepage, cause_exclusion_sewer_backup, cause_exclusion_sump |  |
| V.D.6 The pressure or weight of water unless there is a flood in the area and the flood is the p… | exclusions | encoded | a rule cites or quotes this clause | cause_exclusion_water_pressure |  |
| V.D.7 Power, heating, or cooling failure unless the failure results from direct physical loss by… | exclusions | encoded | a rule cites or quotes this clause | cause_exclusion_utility_failure |  |
| V.D.8 Theft, fire, explosion, wind, or windstorm; | exclusions | encoded | a rule cites or quotes this clause | cause_exclusion_wind |  |
| V.D.9 Anything you or any member of your household do or conspire | exclusions | encoded | a rule cites or quotes this clause | cause_exclusion_conspiracy, cause_exclusion_deliberate_act |  |
| V.D.10 Alteration of the insured property that significantly increases the risk of flooding. | exclusions | encoded | a rule cites or quotes this clause | cause_exclusion_alteration |  |
| V.E We do not insure for loss to any building or personal property located on land leased from… | exclusions | encoded | a rule cites or quotes this clause | cause_exclusion_federal_lease |  |
| V.F We do not pay for the testing for or monitoring of pollutants unless required by law or or… | exclusions | encoded | a rule cites or quotes this clause | cause_exclusion_pollutant_monitoring |  |
| VI DEDUCTIBLES | deductibles | skipped |  |  | a heading: its clauses are the units under it |
| VI.A When a loss is insured under this policy, we will pay only that part of the loss that exce… | deductibles | encoded | a rule cites or quotes this clause | amount_after_deductible, capped_component_amount, component_payment |  |
| VI.B In each loss from flood, separate deductibles apply to the building and personal property … | deductibles | encoded | a rule cites or quotes this clause | scheduled_deductible |  |
| VI.C The deductible does NOT apply to: | deductibles | encoded | a rule cites or quotes this clause | amount_without_deductible |  |
| VI.C.1 III.C.2. Loss Avoidance Measures; | deductibles | encoded | a rule cites or quotes this clause | construction_building_insured_property, loss_avoidance_qualification, no_deductible_loss_avoidance |  |
| VI.C.2 III.C.3. Condominium Loss Assessments; _or | deductibles | approximated | a rule cites the enclosing or an enclosed clause | amount_without_deductible | covered at another level of the numbering: check that the rule carries this clause |
| VI.C.3 III.D. Increased Cost of Compliance. | deductibles | encoded | a rule cites or quotes this clause | no_deductible_coverage_d |  |
| VII GENERAL CONDITIONS | conditions | skipped |  |  | a heading: its clauses are the units under it |
| VII.A Pair and Set Clause | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.A.1 An amount equal to the cost of replacing the lost, damaged, or destroyed article, minus it… | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.A.2 The amount that represents the fair proportion of the total value of the pair or set that … | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.B Other Insurance | conditions | skipped |  |  | a heading: its clauses are the units under it |
| VII.B.1 If a loss insured by this policy is also insured by other insurance that includes flood co… | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.B.1.b The maximum amount of insurance permitted under the Act. | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.B.3 The combined coverage payment under the other NFIP insurance and this policy cannot exceed… | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.C Amendments, Waivers, Assignment | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.C.1 Applicability. The following provisions apply to all instances where the premium paid on t… | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.C.2 Reforming the Policy with Re­ duced Coverage. Except as otherwise provided in VII.D.1, if … | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.C.3 Discovery of Insufficient Premium or Rating Information. If we discover that your premium … | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.C.3.b Insufficient Rating Inform­ ation. If we determine that the rating information we have is … | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.C.4 Coverage Increases. If we do not receive the amounts requested in VII.D.3.a or the additio… | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.C.5 Falsifying Information. However, if we find that you or your agent intentionally did not t… | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.E Policy Renewal | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.E.1 This policy will expire at 12:01 a.m. on the last day of the policy term. | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.E.2 We must receive the payment of the appropriate renewal premium within 30 days of the expir… | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.E.3 If we find, however, that we did not place your renewal notice into the U.S. Postal Servic… | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.E.4 In connection with the renewal of this policy, we may ask you during the policy term to re… | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.F Conditions Suspending or Restricting Insurance | conditions | encoded | a rule cites or quotes this clause | exclusion_increased_hazard |  |
| VII.G Requirements in Case of Loss | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.G.1 Give prompt written notice to us. | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.G.2 As soon as reasonably possible, separate the damaged and | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.G.3 Prepare an inventory of damaged property showing the quantity, description, actual cash va… | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.G.4 Within 60 days after the loss, send us a proof of loss, which is your statement of the amo… | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.G.5 In completing the proof of loss, you must use your own judgment concerning the amount of l… | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.G.6 You must cooperate with the adjuster or representative in the investigation of the claim. | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.G.7 The insurance adjuster whom we hire to investigate your claim may furnish you with a proof… | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.G.8 We have not authorized the adjuster to approve or disapprove claims or to tell you whether… | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.G.9 At our option, we may accept the adjuster’s report of the loss instead of your proof of lo… | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.G.1 At such reasonable times and places that we may designate, you must: | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.G.2 We may request, in writing, that you furnish us with a complete | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.G.3 If we give you written notice within 30 days after we receive your signed, sworn proof of … | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.J Loss Payment | conditions | encoded | a rule cites or quotes this clause | claim_payment_total, component_amount_counted_once, total_payable_amount |  |
| VII.J.1 We will adjust all losses with you. We will pay you unless some other person or entity is … | conditions | encoded | a rule cites or quotes this clause | claim_payment_total, component_amount_counted_once, total_payable_amount |  |
| VII.J.2 If we reject your proof of loss in whole or in part you may: | conditions | approximated | a rule cites the enclosing or an enclosed clause | claim_payment_total, component_amount_counted_once, total_payable_amount | covered at another level of the numbering: check that the rule carries this clause |
| VII.K Abandonment | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.L Salvage | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.L.2 Bear the other expenses of the appraisal and umpire equally. | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.L.1 The word “mortgagee” includes trustee. | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.L.2 Any loss payable under Coverage A—Building Property will be paid to any mortgagee of whom … | general_conditions | encoded | a rule cites or quotes this clause | building_cover_purchased |  |
| VII.L.3 If we deny your claim, that denial will not apply to a valid claim of the mortgagee, if th… | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.M Appraisal | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.M.1 Pay its own appraiser; _and | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.M.4 All of the terms of this policy apply to the mortgagee. | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.M.5 The mortgagee has the right to receive loss payment even if the mortgagee has started fore… | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.M.6 If we decide to cancel or not renew this policy, it will continue in effect for the benefi… | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.M.7 If we pay the mortgagee for any loss and deny payment to you, we are subrogated to all the… | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.O Suit Against Us | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.P Subrogation | general_conditions | skipped |  |  | procedural (general_conditions) |
| VII.Q Continuous Lake Flooding | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.Q.3 Comply with paragraphs Q.1.a through Q.1.d above. | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.Q.c Within 90 days of approval of your claim, you must move your building to a new location ou… | conditions | not_addressed |  |  | no rule cites or quotes this clause |
| VII.R Loss Settlement | loss_settlement | skipped |  |  | a heading: its clauses are the units under it |
| VII.R.1 Introduction | loss_settlement | encoded | a rule cites or quotes this clause | calculated_acv_amount, direct_acv_amount, replacement_cost_maximum |  |
| VII.R.2 Replacement Cost Loss Settlement | loss_settlement | encoded | a rule cites or quotes this clause | replacement_cost_amount, replacement_cost_eighty_percent |  |
| VII.R.3 Special Loss Settlement | loss_settlement | not_addressed |  |  | no rule cites or quotes this clause |
| VII.R.4 Actual Cash Value Loss Settlement | loss_settlement | encoded | a rule cites or quotes this clause | acv_non_principal_residence, calculated_acv_amount, direct_acv_amount, proportional_factor, proportional_repair_amount, proportional_underinsurance, underinsured_settlement_amount |  |
| VII.R.5 Amount of Insurance Required | loss_settlement | encoded | a rule cites or quotes this clause | no_deductible_coverage_d |  |
| VIII POLICY NULLIFICATION, CANCELLATION, AND NON-RENEWAL | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.1 With respect to all insureds under this policy, this policy is void and has no legal force… | general_conditions | encoded | a rule cites or quotes this clause | exclusion_void_policy, void_for_false_statements, void_for_fraud, void_for_misrepresentation |  |
| VIII.2 Policies voided under A.1 cannot be renewed or replaced by a new NFIP policy. | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.3 Policies are void as of the date the acts described in A.1 above were committed. | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.4 Fines, civil penalties, and imprisonment under applicable Federal laws may also apply to t… | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.B Policy Nullification for Reasons Other Than Fraud | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.B.1 This policy is void from its inception, and has no legal force or effect, if: | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.B.2 In such cases, you will be entitled to a full refund of all premium, fees, and surcharges … | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.C Cancellation of the Policy by You | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.C.1 You may cancel this policy in accordance with the terms and conditions of this policy and … | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.C.2 If you cancel this policy, you may be entitled to a full or partial refund of premium, sur… | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.C.1 Cancellation for Underpayment | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.C.2 Cancellation Due to Lack of an Insurable Interest. | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.C.3 Cancellation of Duplicate Policies | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.C.4 Cancellation Due to Physical Alteration of Property | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.E Non-Renewal of the Policy by Us | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.E.1 The community where your insured property is located is suspended or stops participating i… | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.E.2 Your building is otherwise ineligible for flood insurance under the Act; | general_conditions | skipped |  |  | procedural (general_conditions) |
| VIII.E.3 You have failed to provide the information we requested for the purpose of rating the poli… | general_conditions | skipped |  |  | procedural (general_conditions) |
| IX LIBERALIZATION CLAUSE | general_conditions | skipped |  |  | procedural (general_conditions) |
| X WHAT LAW GOVERNS | general_conditions | skipped |  |  | procedural (general_conditions) |

