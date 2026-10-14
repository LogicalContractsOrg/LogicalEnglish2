# Input and output format for the DfE 16-19 funding calculation 2026/27

Field names are the "Public Name" column of the Interface Agreement (PDF section 3,
pages 20-36). A field that is ABSENT from a JSON object is OIA's "unknown".
Dates are "YYYY-MM-DD" strings. Numbers are JSON numbers. Codes that the PDF types
as text (LearnDelFAMCode, LearnAimRefType, AwardOrgCode, LearnAimRef, HRSType,
ValidityCategory, PFTlevelFundingBand, EngGrade, MathGrade) are JSON strings.

One case = one JSON file:

```json
{
  "provider": {
    "UKPRN": 10000001,
    "AreaCostFactor1618": 1.04,
    "EnglishandMathsProportion": 0.03,
    "DisadvantageProportion": 0.12,
    "HistoricLargeProgrammeProportion": 0.01,
    "ProgrammeWeighting": 1.05,
    "RetentionFactor": 0.92,
    "SpecialistResources": false
  },
  "postcode_specialist_resources": [
    {"PostcodeSpecResPostcode": "AB1 2CD", "PostcodeSpecResSpecialistResources": "Y",
     "PostcodeSpecResEffectiveFrom": "2020-08-01", "PostcodeSpecResEffectiveTo": "2030-07-31"}
  ],
  "learner": {
    "LearnRefNumber": "L001",
    "DateOfBirth": "2009-05-01",
    "EngGrade": "4", "MathGrade": "3",
    "LrnFAM_ECF": 1, "LrnFAM_EDF1": 1, "LrnFAM_EDF2": 2, "LrnFAM_EHC": 1, "LrnFAM_HNS": 1,
    "LrnFAM_MCF": 1, "LrnFAM_NLM1": 17, "LrnFAM_NLM2": 18, "LrnFAM_EMH": 1, "LrnFAM_MMH": 1,
    "PlanEEPHours": 60, "PlanLearnHours": 540,
    "PostcodeDisadvantageUplift": 1.1,
    "LearningDeliveries": [
      {
        "LearnAimRef": "ZPROG001", "AimType": 5, "AimSeqNumber": 1, "FundModel": 25, "ProgType": 31,
        "LearnStartDate": "2026-09-07", "LearnPlanEndDate": "2027-06-30", "LearnActEndDate": "2027-06-20",
        "CompStatus": 1, "WithdrawReason": 40,
        "LearnAimRefTitle": "...", "LearnAimRefType": "0001", "AwardOrgCode": "AQA",
        "EFACOFType": 2, "SectorSubjectAreaTier2": 14.1, "NotionalNVQLevel": 3, "GuidedLearningHours": 360,
        "DelLocPostcode": "AB1 2CD", "PFProgrammeCode": 1,
        "LearnDelCatRef": 37, "LearnDelCatDateFrom": "2020-08-01", "LearnDelCatDateTo": "2030-07-31",
        "FAMs": [ {"LearnDelFAMType": "SOF", "LearnDelFAMCode": "107",
                   "LearnDelFAMDateFrom": "2026-09-07", "LearnDelFAMDateTo": "2027-06-30"} ],
        "LARSValidities": [ {"ValidityCategory": "1619_EFA", "ValidityStartDate": "2015-08-01",
                              "ValidityLastNewStartDate": "2030-07-31"} ],
        "LARSProgrammeFunding": [ {"PFTlevelFundingBand": "9", "PFTlevelPCW": 1.58,
                                   "PFEffectiveFrom": "2020-08-01", "PFEffectiveTo": "2030-07-31"} ],
        "HRSRecords": [ {"HRSType": "HRS", "HRSCode": 2, "HRSAmount": 1600} ]
      }
    ]
  }
}
```

The interface agreement (page 29) lists LearnDelCatRef / LearnDelCatDateFrom /
LearnDelCatDateTo as attributes of the learning delivery's LARS categories (entity
LearningDeliveryLARSCategory, one to many). If the rules treat categories as a
list, a delivery may instead carry `"LARSCategories": [{"LearnDelCatRef":..,
"LearnDelCatDateFrom":.., "LearnDelCatDateTo":..}]`. Accept both forms; prefer the
list.

## Output: one JSON object per case, keyed by the Public Names of the Learner
outputs (pages 34-36), e.g.

```json
{"AcadMonthPayment": 2, "AcadProg": false, "ActualDaysILCurrYear": 287, "AreaCostFact1618Hist": 1.04,
 "Block1DisadvUpliftNew": 1.1, "Block2DisadvElementsNew": 0, "ConditionOfFundingEnglish": "...",
 "ConditionOfFundingMaths": "...", "CoreAimSeqNumber": 1, "ProgAimSeqNumber": 1, "FullTimeEquiv": 0.9375,
 "FundLine": "...", "LearnerActEndDate": "2027-06-30", "LearnerPlanEndDate": "2027-06-30",
 "LearnerStartDate": "2026-09-07", "NatRate": 5256, "OnProgPayment": 6152.37, "PlannedDaysILCurrYear": 297,
 "ProgWeightHist": 1.05, "ProgWeightNew": 1.0, "PrvDisadvPropnHist": 0.12, "PrvHistLrgProgPropn": 0.01,
 "PrvRetentFactHist": 0.92, "PrvHistEnglishMathsProportion": 0.03, "LearnerEnglishMathsInstances": 1,
 "RateBand": "...", "RetentNew": 1, "StartFund": true, "ThresholdDays": 42, "TLevelStudent": false,
 "TransitionStudent": false, "TLevelAdditionalHours": 0, "Year3ofTlevelStudyProgramme": false,
 "TLevelTQLearnAimRef": null, "TLevelOSLearnAimRef": null, "TLevelProgAimActEndDate": null,
 "TLevelProgAimPlanEndDate": null, "TLevelProgAimStartDate": null}
```

Use `null` for OIA's "unknown" or "uncertain". Do not round numbers (OIA keeps
the precision of the table on page 35; the comparison will allow 1e-6).
