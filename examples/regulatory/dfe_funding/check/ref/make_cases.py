#!/usr/bin/env python3
"""Writes the test cases into cases/ (one JSON file per case, schema.md format)."""
import copy
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "cases")

PROVIDER = {
    "UKPRN": 10000001, "AreaCostFactor1618": 1.04, "EnglishandMathsProportion": 0.03,
    "DisadvantageProportion": 0.12, "HistoricLargeProgrammeProportion": 0.01,
    "ProgrammeWeighting": 1.05, "RetentionFactor": 0.92, "SpecialistResources": False,
}
SOF = [{"LearnDelFAMType": "SOF", "LearnDelFAMCode": "107"}]
V1619 = [{"ValidityCategory": "1619_EFA", "ValidityStartDate": "2015-08-01", "ValidityLastNewStartDate": "2030-07-31"}]


def aim(seq, ref, start="2026-09-07", plan="2027-06-30", act=None, comp=1, aimtype=4, ref_type="0001",
        title="Generic qualification", ssa=14.1, fm=25, prog=None, wr=None, fams=None, validities=None,
        extra=None):
    d = {"LearnAimRef": ref, "AimType": aimtype, "AimSeqNumber": seq, "FundModel": fm,
         "LearnStartDate": start, "LearnPlanEndDate": plan, "CompStatus": comp,
         "LearnAimRefTitle": title, "LearnAimRefType": ref_type, "AwardOrgCode": "PEARSON",
         "EFACOFType": 2, "SectorSubjectAreaTier2": ssa, "NotionalNVQLevel": 3, "GuidedLearningHours": 360,
         "DelLocPostcode": "AB1 2CD",
         "FAMs": copy.deepcopy(SOF if fams is None else fams),
         "LARSValidities": copy.deepcopy(V1619 if validities is None else validities)}
    if prog is not None:
        d["ProgType"] = prog
    if act is not None:
        d["LearnActEndDate"] = act
    if wr is not None:
        d["WithdrawReason"] = wr
    if extra:
        d.update(extra)
    return d


def gcse_eng(seq, start="2026-09-07", plan="2027-06-30", act=None, comp=1, fm=25, cof_type=1):
    return aim(seq, "60037155", start, plan, act, comp, ref_type="0003", title="GCSE English Language",
               ssa=12.1, fm=fm, extra={"EFACOFType": cof_type},
               validities=V1619 + [{"ValidityCategory": "EFACONFUNDENGLISH", "ValidityStartDate": "2015-08-01"}])


def gcse_maths(seq, start="2026-09-07", plan="2027-06-30", act=None, comp=1, fm=25, cof_type=1):
    return aim(seq, "60183337", start, plan, act, comp, ref_type="0003", title="GCSE Mathematics",
               ssa=2.2, fm=fm, extra={"EFACOFType": cof_type},
               validities=V1619 + [{"ValidityCategory": "EFACONFUNDMATHS", "ValidityStartDate": "2015-08-01",
                                    "ValidityLastNewStartDate": "2030-07-31"}])


def btec_core(seq=1, ssa=4.1, start="2026-09-07", plan="2027-06-30", act=None, comp=1, wr=None, title=None,
              ref="60312345", ref_type="1413"):
    return aim(seq, ref, start, plan, act, comp, aimtype=5, ref_type=ref_type,
               title=title or "BTEC Level 3 Extended Diploma", ssa=ssa, wr=wr)


def learner(ref, dob="2010-03-15", lds=(), eng="4", maths="4", plh=540, eep=60, **fam):
    d = {"LearnRefNumber": ref, "DateOfBirth": dob, "PlanLearnHours": plh, "PlanEEPHours": eep,
         "PostcodeDisadvantageUplift": 1.1, "LearningDeliveries": list(lds)}
    if eng is not None:
        d["EngGrade"] = eng
    if maths is not None:
        d["MathGrade"] = maths
    d.update(fam)
    for k in [k for k, v in d.items() if v is None]:
        del d[k]
    return d


CASES = {}


def case(name, lrn, provider=None, postcodes=None):
    c = {"provider": copy.deepcopy(PROVIDER if provider is None else provider), "learner": lrn}
    if postcodes is not None:
        c["postcode_specialist_resources"] = postcodes
    CASES[name] = c


# --------------------------------------------------------------------------- study programmes
case("sp_vocational_band5_age16_engineering_completed",
     learner("SP01", lds=[btec_core(1, 4.1, act="2027-06-20", comp=2)]))
case("sp_vocational_continuing_age17_ssa_9_1_medium",
     learner("SP02", dob="2009-01-20", lds=[btec_core(1, 9.1)]))
case("sp_vocational_ssa_7_4_high_and_13_1",
     learner("SP03", lds=[btec_core(1, 7.4), aim(2, "60311111", ssa=13.1)]))
case("sp_alevel_academic_three_alevels_two_year",
     learner("SP04", lds=[aim(1, "50079116", plan="2028-06-30", aimtype=5, ref_type="0001", title="A level Mathematics", ssa=2.2),
                          aim(2, "50079128", plan="2028-06-30", ref_type="0001", title="A level History", ssa=10.1),
                          aim(3, "50079130", plan="2028-06-30", ref_type="0001", title="A level English Literature", ssa=12.1)]))
case("sp_alevel_science_two_uplift_aims_low_pcw",
     learner("SP05", lds=[aim(1, "50080001", plan="2028-06-30", aimtype=5, ref_type="0001", title="A level Physics", ssa=2.1,
                              extra={"LARSCategories": [{"LearnDelCatRef": 64, "LearnDelCatDateFrom": "2020-08-01"}]}),
                          aim(2, "50080002", plan="2028-06-30", ref_type="0001", title="A level Chemistry", ssa=2.1,
                              extra={"LearnDelCatRef": 64, "LearnDelCatDateFrom": "2020-08-01", "LearnDelCatDateTo": "2030-07-31"}),
                          aim(3, "50080003", plan="2028-06-30", ref_type="0001", title="A level Psychology", ssa=2.1)]))
case("sp_alevel_one_uplift_aim_no_low_pcw",
     learner("SP06", lds=[aim(1, "50080001", plan="2028-06-30", aimtype=5, ref_type="0001", title="A level Physics", ssa=2.1,
                              extra={"LARSCategories": [{"LearnDelCatRef": 64}]}),
                          aim(2, "50079128", plan="2028-06-30", ref_type="0001", title="A level History", ssa=10.1)]))
case("sp_vocational_ssa_1_1_low_pcw",
     learner("SP07", lds=[btec_core(1, 1.1, title="Diploma in Medical Science")]))
case("sp_vocational_ssa_2_1_psychology_not_low",
     learner("SP08", lds=[btec_core(1, 2.1, title="Extended Certificate in Applied Psychology")]))
case("sp_vocational_ssa_2_1_applied_science_low",
     learner("SP09", lds=[btec_core(1, 2.1, title="Extended Diploma in Applied Science")]))
case("sp_ssa_3_1_postcode_specialist_Y",
     learner("SP10", lds=[btec_core(1, 3.1, title="Diploma in Agriculture")]),
     postcodes=[{"PostcodeSpecResPostcode": "AB1 2CD", "PostcodeSpecResSpecialistResources": "Y",
                 "PostcodeSpecResEffectiveFrom": "2020-08-01", "PostcodeSpecResEffectiveTo": "2030-07-31"}])
case("sp_ssa_3_2_no_postcode_data_provider_specialist",
     learner("SP11", lds=[btec_core(1, 3.2, title="Diploma in Horticulture")]),
     provider=dict(PROVIDER, SpecialistResources=True))
case("sp_ssa_3_3_postcode_data_other_postcode_only",
     learner("SP12", lds=[btec_core(1, 3.3, title="Diploma in Animal Care")]),
     provider=dict(PROVIDER, SpecialistResources=True),
     postcodes=[{"PostcodeSpecResPostcode": "ZZ9 9ZZ", "PostcodeSpecResSpecialistResources": "Y",
                 "PostcodeSpecResEffectiveFrom": "2020-08-01"}])
case("sp_ssa_3_1_provider_specialist_unknown",
     learner("SP13", lds=[btec_core(1, 3.1, title="Diploma in Agriculture")]),
     provider={k: v for k, v in PROVIDER.items() if k != "SpecialistResources"})
case("sp_ssa_3_1_postcode_record_ended_31_july_2026",
     learner("SP14", lds=[btec_core(1, 3.1, title="Diploma in Agriculture")]),
     postcodes=[{"PostcodeSpecResPostcode": "AB1 2CD", "PostcodeSpecResSpecialistResources": "Y",
                 "PostcodeSpecResEffectiveFrom": "2020-08-01", "PostcodeSpecResEffectiveTo": "2026-07-31"}])
case("sp_ib_diploma_academic",
     learner("SP15", lds=[aim(1, "60000001", plan="2028-06-30", aimtype=5, ref_type="0016", title="IB Diploma",
                              ssa=12.1, extra={"AwardOrgCode": "ib"})]))
case("sp_core_maths_academic_with_vocational_others",
     learner("SP16", lds=[aim(1, "60147830", aimtype=5, ref_type="0016", title="Core Maths", ssa=2.2),
                          aim(2, "60311111", ssa=4.1)]))
case("sp_aaq_academic_and_gcse_core",
     learner("SP17", lds=[aim(1, "61000001", plan="2028-06-30", aimtype=5, ref_type="1469", title="AAQ in Applied Science", ssa=2.1)]))
case("sp_general_studies_core_not_academic",
     learner("SP18", lds=[aim(1, "50000099", aimtype=5, ref_type="0001", title="A level General Studies", ssa=1.1)]))
case("sp_missing_aim_ref_type_not_academic",
     learner("SP19", lds=[aim(1, "50000100", aimtype=5, ssa=4.2)]))
del CASES["sp_missing_aim_ref_type_not_academic"]["learner"]["LearningDeliveries"][0]["LearnAimRefType"]
case("sp_kings_trust_team_core_aim",
     learner("SP20", dob="2008-11-02", plh=400, eep=100,
             lds=[aim(1, "60023995", aimtype=5, ref_type="1413", title="Kings Trust TEAM", ssa=14.2,
                      fams=SOF + [{"LearnDelFAMType": "ldm", "LearnDelFAMCode": "331"}])]))
# --------------------------------------------------------------------------- bands and ages
case("sp_age18_not_hns_500h_band4a",
     learner("SP21", dob="2008-05-01", plh=450, eep=50, lds=[btec_core(1, 15.2)]))
case("sp_age18_hns_600h_band5_high_needs_line",
     learner("SP22", dob="2008-05-01", plh=560, eep=40, LrnFAM_HNS=1, lds=[btec_core(1, 14.1)]))
case("sp_age17_500h_band4b",
     learner("SP23", dob="2009-05-01", plh=450, eep=50, lds=[btec_core(1, 15.2)]))
case("sp_400h_band3", learner("SP24", plh=380, eep=20, lds=[btec_core(1, 15.3)]))
case("sp_320h_band2", learner("SP25", plh=300, eep=20, lds=[btec_core(1, 15.3)]))
case("sp_200h_band1_fte", learner("SP26", plh=180, eep=20, lds=[btec_core(1, 15.3)]))
case("sp_only_planned_learning_hours_known",
     learner("SP27", plh=600, eep=None, lds=[btec_core(1, 15.3)]))
case("sp_no_hours_at_all_zero_hours_band1",
     learner("SP28", plh=None, eep=None, lds=[btec_core(1, 15.3)]))
case("sp_age20_ehc_19_24_ehcp_line",
     learner("SP29", dob="2006-02-01", LrnFAM_EHC=1, LrnFAM_HNS=1, lds=[btec_core(1, 14.1)]))
case("sp_age25_ehc_19plus_continuing_line",
     learner("SP30", dob="2001-06-01", LrnFAM_EHC=1, lds=[btec_core(1, 14.1)]))
case("sp_age19_no_ehc_19plus_continuing",
     learner("SP31", dob="2007-04-01", lds=[btec_core(1, 14.1)]))
case("direct_funded_14_16_age15",
     learner("DF01", dob="2011-03-01", eng="NONE", maths="NONE",
             lds=[btec_core(1, 14.1, ref="60399999")]))
for c in CASES["direct_funded_14_16_age15"]["learner"]["LearningDeliveries"]:
    c["FAMs"].append({"LearnDelFAMType": "LDM", "LearnDelFAMCode": "320"})
case("age14_not_direct_funded_1619_line",
     learner("DF02", dob="2012-01-10", lds=[btec_core(1, 14.1)]))
case("summer_school_age15_june_start",
     learner("SS01", dob="2011-04-01", plh=60, eep=0,
             lds=[btec_core(1, 14.1, start="2027-06-15", plan="2027-07-20")]))
# --------------------------------------------------------------------------- dates and retention
case("early_leaver_below_qualifying_period",
     learner("RT01", lds=[btec_core(1, 4.1, act="2026-09-30", comp=3, wr=40)]))
case("short_programme_qualifying_14_days",
     learner("RT02", plh=180, eep=20, lds=[btec_core(1, 15.3, start="2027-02-01", plan="2027-03-31", act="2027-02-25", comp=2)]))
case("withdrawn_after_qp_vocational_half_retention",
     learner("RT03", lds=[btec_core(1, 4.1, act="2027-01-15", comp=3, wr=40)]))
case("withdrawn_transfer_reason_2_counts_retained",
     learner("RT04", lds=[btec_core(1, 4.1, act="2027-01-15", comp=3, wr=2)]))
case("two_year_withdrawn_after_first_year_end_retained",
     learner("RT05", lds=[btec_core(1, 4.1, plan="2028-06-30", act="2027-07-10", comp=3, wr=40)]))
case("two_year_withdrawn_before_30_june_not_retained",
     learner("RT06", lds=[btec_core(1, 4.1, plan="2028-06-30", act="2027-06-20", comp=3, wr=40)]))
case("academic_core_withdrawn_other_alevel_completed",
     learner("RT07", lds=[aim(1, "50079116", act="2027-01-10", comp=3, wr=40, aimtype=5, ref_type="0001", ssa=2.2),
                          aim(2, "50079128", act="2027-06-25", comp=2, ref_type="0001", ssa=10.1)]))
case("academic_all_withdrawn",
     learner("RT08", lds=[aim(1, "50079116", act="2027-01-10", comp=3, wr=40, aimtype=5, ref_type="0001", ssa=2.2),
                          aim(2, "50079128", act="2027-01-10", comp=3, wr=40, ref_type="0001", ssa=10.1)]))
case("continuing_from_previous_year_payment_period_1",
     learner("DT01", dob="2008-10-01", lds=[btec_core(1, 4.1, start="2025-09-08", plan="2027-06-30")]))
case("january_start_payment_period_6",
     learner("DT02", lds=[btec_core(1, 4.1, start="2027-01-11", plan="2027-07-16")]))
case("ended_previous_year_not_in_year",
     learner("DT03", lds=[btec_core(1, 4.1, start="2025-09-08", plan="2026-06-30", act="2026-06-30", comp=2)]))
case("start_after_funding_year",
     learner("DT04", lds=[btec_core(1, 4.1, start="2027-08-20", plan="2028-06-30")]))
case("planned_end_missing_unknown",
     learner("DT05", lds=[btec_core(1, 4.1)]))
del CASES["planned_end_missing_unknown"]["learner"]["LearningDeliveries"][0]["LearnPlanEndDate"]
case("multiple_core_aims_latest_start_and_tie_on_seq",
     learner("CA01", lds=[btec_core(1, 4.1, start="2026-09-07", act="2026-11-30", comp=3, wr=40),
                          btec_core(2, 9.1, start="2026-12-01", plan="2027-06-30", ref="60300001"),
                          btec_core(3, 7.4, start="2026-12-01", plan="2027-06-30", ref="60300002")]))
case("no_core_aim",
     learner("CA02", lds=[aim(1, "60311111", ssa=4.1)]))
case("sof_missing_other_fundline_unknown",
     learner("FL01", lds=[aim(1, "60312345", aimtype=5, ssa=4.1, fams=[])]))
case("date_of_birth_missing",
     learner("FL02", dob=None, lds=[btec_core(1, 4.1)]))
case("provider_factors_missing",
     learner("PR01", lds=[btec_core(1, 4.1)]), provider={"UKPRN": 10000002})
# --------------------------------------------------------------------------- condition of funding
case("cof_has_english_studying_has_maths_not_studying",
     learner("CF01", eng="5", maths="4", lds=[btec_core(1, 4.1), gcse_eng(2)]))
case("cof_doesnt_have_studying_with_min_hours",
     learner("CF02", eng="U", maths="2", LrnFAM_EMH=1, LrnFAM_MMH=1,
             lds=[btec_core(1, 4.1), gcse_eng(2), gcse_maths(3)]))
case("cof_doesnt_have_studying_without_min_hours",
     learner("CF03", eng="1", maths="E", lds=[btec_core(1, 4.1), gcse_eng(2), gcse_maths(3)]))
case("cof_exempt_ecf1_mcf2",
     learner("CF04", eng="2", maths="1", LrnFAM_ECF=1, LrnFAM_MCF=2, lds=[btec_core(1, 4.1)]))
case("cof_below_d_with_fsl2_pass",
     learner("CF05", eng="E", maths="2", LrnFAM_ECF=5, LrnFAM_MCF=5, lds=[btec_core(1, 4.1)]))
case("cof_grade3_not_studying_band5",
     learner("CF06", eng="3", maths="D", lds=[btec_core(1, 4.1)]))
case("cof_grade3_studying_gcse_cof_type1_min_hours",
     learner("CF07", eng="3", maths="3", LrnFAM_EMH=1, LrnFAM_MMH=1,
             lds=[btec_core(1, 4.1), gcse_eng(2), gcse_maths(3)]))
case("cof_grade3_studying_gcse_no_min_hours",
     learner("CF08", eng="3", maths="3", lds=[btec_core(1, 4.1), gcse_eng(2), gcse_maths(3)]))
case("cof_grade3_studying_non_gcse_cof_type2",
     learner("CF09", eng="3", maths="3", LrnFAM_EMH=1, LrnFAM_MMH=1,
             lds=[btec_core(1, 4.1), gcse_eng(2, cof_type=2), gcse_maths(3, cof_type=2)]))
case("cof_grade3_band3_part_time",
     learner("CF10", eng="3", maths="3", plh=380, eep=20, LrnFAM_EMH=1, lds=[btec_core(1, 4.1), gcse_eng(2, cof_type=2)]))
case("cof_does_not_apply_under_150_hours",
     learner("CF11", eng="U", maths="U", plh=100, eep=20, lds=[btec_core(1, 4.1)]))
case("cof_does_not_apply_age15",
     learner("CF12", dob="2011-02-01", eng="U", maths="U", lds=[btec_core(1, 4.1)]))
case("cof_grades_missing",
     learner("CF13", eng=None, maths=None, lds=[btec_core(1, 4.1)]))
case("cof_ecf3_mcf3_equivalent_held",
     learner("CF14", eng="3", maths="U", LrnFAM_ECF=3, LrnFAM_MCF=3, lds=[btec_core(1, 4.1)]))
case("cof_ecf4_studying_elsewhere",
     learner("CF15", eng="U", maths="3", LrnFAM_ECF=4, LrnFAM_MCF=4, LrnFAM_EMH=1, lds=[btec_core(1, 4.1)]))
case("cof_gcse_in_other_funding_model_counts",
     learner("CF16", eng="4", maths="U", LrnFAM_MMH=1, lds=[btec_core(1, 4.1), gcse_maths(2, fm=35)]))
case("cof_gcse_aim_early_leaver_not_valid_start",
     learner("CF17", eng="U", maths="U", LrnFAM_EMH=1,
             lds=[btec_core(1, 4.1), gcse_eng(2, act="2026-09-20", comp=3), gcse_maths(3, start="2027-06-01", plan="2027-06-10")]))
case("cof_letter_grades_lowercase",
     learner("CF18", eng="c", maths="d", lds=[btec_core(1, 4.1)]))
case("cof_validity_last_new_start_passed",
     learner("CF19", eng="U", maths="U", LrnFAM_EMH=1, LrnFAM_MMH=1,
             lds=[btec_core(1, 4.1),
                  aim(2, "60037155", ref_type="0003", ssa=12.1,
                      validities=[{"ValidityCategory": "EfaConFundEnglish", "ValidityStartDate": "2015-08-01",
                                   "ValidityLastNewStartDate": "2026-07-31"}]),
                  aim(3, "60183337", ref_type="0003", ssa=2.2,
                      validities=[{"ValidityCategory": "EFACONFUNDMATHS", "ValidityStartDate": "2015-08-01"}])]))
# --------------------------------------------------------------------------- disadvantage / instances
case("disadvantage_block2_both_edf_and_no_postcode_uplift",
     learner("DS01", eng="3", maths="2", LrnFAM_EDF1=1, LrnFAM_EDF2=2, PostcodeDisadvantageUplift=None,
             lds=[btec_core(1, 4.1)]))
case("disadvantage_block2_english_only_instances_2",
     learner("DS02", eng="D", maths="U", LrnFAM_EDF1=2, LrnFAM_ECF=4, lds=[btec_core(1, 4.1)]))
case("instances_ecf2_excludes_english",
     learner("DS03", eng="3", maths="3", LrnFAM_ECF=2, LrnFAM_MCF=1, lds=[btec_core(1, 4.1)]))
case("instances_fsl2_excluded",
     learner("DS04", eng="2", maths="3", LrnFAM_ECF=5, lds=[btec_core(1, 4.1)]))
# --------------------------------------------------------------------------- T levels


def tl_prog(seq=1, start="2026-09-07", plan="2028-06-30", hours=1730, act=None, comp=1, hrs=True, wr=None):
    d = aim(seq, "ZPROG001", start, plan, act, comp, aimtype=1, ref_type="ZZZZ", title="Programme aim",
            ssa=4.1, prog=31, wr=wr)
    if hrs:
        d["HRSRecords"] = [{"HRSType": "hrs", "HRSCode": 2, "HRSAmount": hours}]
    return d


def tl_tq(seq=2, start="2026-09-07", plan="2028-06-30", ref="60358294", act=None, comp=1, wr=None):
    return aim(seq, ref, start, plan, act, comp, aimtype=5, ref_type="1468",
               title="T Level Technical Qualification in Digital Production", ssa=6.1, prog=31, wr=wr)


def tl_os(seq=3, start="2026-09-07", plan="2028-06-30", band="9", pcw=1.44, ref="ZTLOS001", comp=1,
          pc=None, pf=True, act=None):
    d = aim(seq, ref, start, plan, act, comp, aimtype=3, ref_type="ZZZZ", title="Occupational specialism",
            ssa=6.1, prog=31)
    if pf:
        rec = {"PFTlevelFundingBand": band, "PFTlevelPCW": pcw, "PFEffectiveFrom": "2020-08-01"}
        if pc is not None:
            rec["PFProgrammeCode"] = pc
        d["LARSProgrammeFunding"] = [rec]
    return d


def tl_case(name, ref, dob="2010-01-10", progs=None, tq=None, oss=None, extra_lds=(), provider=None, postcodes=None, **fam):
    lds = (progs or [tl_prog()]) + (tq or [tl_tq()]) + (oss or [tl_os()]) + list(extra_lds)
    case(name, learner(ref, dob=dob, plh=None, eep=None, lds=lds, **fam), provider=provider, postcodes=postcodes)


tl_case("tlevel_band9_1730_hours", "TL01")
tl_case("tlevel_band8_uplifted_1580_hours", "TL02", progs=[tl_prog(hours=1580)], oss=[tl_os(band="8 uplifted", pcw=1.58)])
tl_case("tlevel_band9_only_1400_hours_drops_to_band7", "TL03", progs=[tl_prog(hours=1400)])
tl_case("tlevel_band8_uplifted_1400_hours_band7_uplifted", "TL04", progs=[tl_prog(hours=1400)], oss=[tl_os(band="8 uplifted")])
tl_case("tlevel_band6_uplifted_1200_hours", "TL05", progs=[tl_prog(hours=1200)], oss=[tl_os(band="6 uplifted", pcw=1.29)])
tl_case("tlevel_no_lars_funding_defaults_band5", "TL06", progs=[tl_prog(hours=1000)], oss=[tl_os(pf=False)])
tl_case("tlevel_500_hours_falls_to_band4b", "TL07", progs=[tl_prog(hours=500)])
tl_case("tlevel_year3_not_repeating_not_a_start", "TL08",
        progs=[tl_prog(start="2024-09-09", plan="2026-12-18", hours=600)],
        tq=[tl_tq(start="2024-09-09", plan="2026-12-18")], oss=[tl_os(start="2024-09-09", plan="2026-12-18")])
tl_case("tlevel_year3_repeating_final_year_nlm22", "TL09",
        progs=[tl_prog(start="2024-09-09", plan="2027-06-30", hours=700)],
        tq=[tl_tq(start="2024-09-09", plan="2027-06-30")], oss=[tl_os(start="2024-09-09", plan="2027-06-30")],
        LrnFAM_NLM2=22)
tl_case("tlevel_2021_22_starter_additional_40_hours", "TL10", dob="2005-09-01",
        progs=[tl_prog(start="2021-09-06", plan="2027-06-30", hours=1540)],
        tq=[tl_tq(start="2021-09-06", plan="2027-06-30")], oss=[tl_os(start="2021-09-06", plan="2027-06-30")],
        LrnFAM_NLM1=22)
tl_case("tlevel_programme_aim_without_hrs_record", "TL11", progs=[tl_prog(hrs=False)])
tl_case("tlevel_os_programme_code_52_postcode_Y_pcw_2_09", "TL12", oss=[tl_os(pc=52)],
        postcodes=[{"PostcodeSpecResPostcode": "AB1 2CD", "PostcodeSpecResSpecialistResources": "Y",
                    "PostcodeSpecResEffectiveFrom": "2020-08-01"}])
tl_case("tlevel_two_os_aims_one_continuing", "TL13",
        oss=[tl_os(3, start="2026-09-07", band="9", pcw=1.44, ref="ZTLOS001", comp=1),
             tl_os(4, start="2027-01-04", band="7", pcw=1.73, ref="ZTLOS002", comp=3, act="2027-02-01")])
tl_case("tlevel_two_os_aims_both_closed_latest_wins", "TL14",
        oss=[tl_os(3, start="2026-09-07", band="9", pcw=1.44, ref="ZTLOS001", comp=2, act="2027-06-01"),
             tl_os(4, start="2027-01-04", band="8", pcw=1.73, ref="ZTLOS002", comp=3, act="2027-02-01")])
tl_case("tlevel_second_year_with_gcse_maths_cof", "TL15",
        progs=[tl_prog(start="2025-09-08", plan="2027-06-30")],
        tq=[tl_tq(start="2025-09-08", plan="2027-06-30")], oss=[tl_os(start="2025-09-08", plan="2027-06-30")],
        extra_lds=[gcse_maths(5)], maths="3", LrnFAM_MMH=1)
tl_case("tlevel_withdrawn_early_retention", "TL16",
        progs=[tl_prog(act="2027-03-01", comp=3, wr=40)], tq=[tl_tq(act="2027-03-01", comp=3, wr=40)],
        oss=[tl_os(act="2027-03-01", comp=3)])
tl_case("tlevel_pre_2022_start_cof_does_not_apply", "TL17", dob="2004-09-01",
        progs=[tl_prog(start="2022-07-15", plan="2027-06-30", hours=1500)],
        tq=[tl_tq(start="2022-07-15", plan="2027-06-30")], oss=[tl_os(start="2022-07-15", plan="2027-06-30")],
        eng="U", maths="U", LrnFAM_NLM1=22)


def tr_case(name, ref, core_ref, provider=None, postcodes=None, ssa=14.1):
    lds = [aim(1, "ZPROG001", aimtype=1, ref_type="ZZZZ", prog=30, title="Programme aim", ssa=ssa),
           aim(2, core_ref, aimtype=5, ref_type="ZZZZ", prog=30, title="T Level Foundation Year", ssa=ssa)]
    case(name, learner(ref, plh=600, eep=100, eng="3", maths="U", lds=lds), provider=provider, postcodes=postcodes)


tr_case("transition_ztpr0005_pcw_1_73", "TR01", "ZTPR0005")
tr_case("transition_ztpr0001_provider_specialist_2_09", "TR02", "ZTPR0001", provider=dict(PROVIDER, SpecialistResources=True))
tr_case("transition_ztpr0001_no_specialist_national_1_58", "TR03", "ZTPR0001")
tr_case("transition_unlisted_core_ref_pcw_1", "TR04", "ZTPR0099")


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".json"):
            os.remove(os.path.join(OUT, f))
    for name, c in CASES.items():
        with open(os.path.join(OUT, name + ".json"), "w") as fh:
            json.dump(c, fh, indent=1)
    print(len(CASES), "cases written to", OUT)


if __name__ == "__main__":
    main()
