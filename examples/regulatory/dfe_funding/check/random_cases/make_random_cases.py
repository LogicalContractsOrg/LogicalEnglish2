import json, random, datetime, os
random.seed(20261013)
D=os.path.dirname(os.path.abspath(__file__))
def date(y0,y1):
    a=datetime.date(y0,1,1).toordinal(); b=datetime.date(y1,12,31).toordinal()
    return datetime.date.fromordinal(random.randint(a,b)).isoformat()
def maybe(p,v): return v if random.random()<p else None
GR=["A*","A","B","C","D","E","U","X","NONE","9","8","7","6","5","4","3","2","1","c","d"]
SSA=[1.1,1.2,2.1,3.1,3.2,3.3,3.4,4.1,4.2,4.3,5.1,5.2,5.3,6.1,7.1,7.3,7.4,9.1,9.2,13.1,13.2,14.1,15.3]
REFTYPE=["0001","0002","0003","2999","0016","1401","1446","1420","1440","1469","1468","9999"]
for n in range(300):
    tl = random.random()<0.35
    trans = (not tl) and random.random()<0.15
    prov={"UKPRN":1,"AreaCostFactor1618":random.choice([1.0,1.04,1.2]),"EnglishandMathsProportion":random.choice([0,0.02,0.05]),
          "DisadvantageProportion":random.choice([0.05,0.12]),"HistoricLargeProgrammeProportion":random.choice([0,0.01]),
          "ProgrammeWeighting":random.choice([1.0,1.05,1.2]),"RetentionFactor":random.choice([0.85,0.92,1.0]),
          "SpecialistResources":random.random()<0.3}
    pcs=[]
    for i in range(random.randint(0,2)):
        pcs.append({"PostcodeSpecResPostcode":random.choice(["AB1 2CD","ZZ9 9ZZ"]),"PostcodeSpecResSpecialistResources":random.choice(["Y","N"]),
                    "PostcodeSpecResEffectiveFrom":random.choice(["2020-08-01","2026-09-01"]),"PostcodeSpecResEffectiveTo":random.choice(["2030-07-31","2026-07-31","2026-07-30"])})
    lr={"LearnRefNumber":f"F{n:03d}","DateOfBirth":date(2001,2012),"EngGrade":random.choice(GR),"MathGrade":random.choice(GR),
        "PlanLearnHours":random.choice([100,250,350,450,520,560,600,700]),"PlanEEPHours":random.choice([0,20,40,60]),
        "PostcodeDisadvantageUplift":maybe(0.7,random.choice([1.0,1.1,1.3]))}
    for k in ["LrnFAM_ECF","LrnFAM_MCF"]:
        v=maybe(0.5,random.randint(1,5));  lr[k]=v
    for k,choices in [("LrnFAM_EDF1",[1,2]),("LrnFAM_EDF2",[1,2]),("LrnFAM_EHC",[1]),("LrnFAM_HNS",[1]),("LrnFAM_NLM1",[17,22]),("LrnFAM_NLM2",[18,22]),("LrnFAM_EMH",[1]),("LrnFAM_MMH",[1])]:
        lr[k]=maybe(0.3,random.choice(choices))
    lr={k:v for k,v in lr.items() if v is not None}
    dels=[]; seq=1
    start=date(2021,2027)
    def ld(aimtype, progtype=None, ref=None, reftype=None, extra=None):
        global seq
        s=random.choice([start, date(2024,2027)])
        pe=(datetime.date.fromisoformat(s)+datetime.timedelta(days=random.choice([10,60,200,300,700]))).isoformat()
        d={"LearnAimRef":ref or f"{random.randint(50000000,60200000)}","AimType":aimtype,"AimSeqNumber":seq,"FundModel":random.choice([25,25,25,35]),
           "LearnStartDate":s,"LearnPlanEndDate":pe,"CompStatus":random.choice([1,1,2,3,6]),
           "LearnAimRefType":reftype or random.choice(REFTYPE),"SectorSubjectAreaTier2":maybe(0.85,random.choice(SSA)),
           "EFACOFType":random.choice([1,2]),"DelLocPostcode":random.choice(["AB1 2CD","ZZ9 9ZZ"]),
           "LearnAimRefTitle":random.choice(["A level History","A level Psychology","General Studies A","Critical Thinking AS","BTEC Engineering","GCSE English","GCSE Maths"]),
           "AwardOrgCode":random.choice(["AQA","IB","ib","PEARSON"])}
        if d["CompStatus"]==3: d["WithdrawReason"]=random.choice([2,7,47,40])
        if d["CompStatus"] in (2,3) and random.random()<0.8:
            d["LearnActEndDate"]=(datetime.date.fromisoformat(s)+datetime.timedelta(days=random.choice([5,20,100,300,650]))).isoformat()
        if progtype is not None: d["ProgType"]=progtype
        fams=[{"LearnDelFAMType":"SOF","LearnDelFAMCode":random.choice(["107","107","105"])}]
        if random.random()<0.1: fams.append({"LearnDelFAMType":random.choice(["LDM","ldm"]),"LearnDelFAMCode":random.choice(["320","331"])})
        d["FAMs"]=fams
        if random.random()<0.3: d["LARSCategories"]=[{"LearnDelCatRef":random.choice([64,37])}]
        if random.random()<0.6:
            d["LARSValidities"]=[{"ValidityCategory":random.choice(["EFACONFUNDENGLISH","EFACONFUNDMATHS","1619_EFA","efaconfundmaths"]),
                                  "ValidityStartDate":random.choice(["2015-08-01","2027-01-01"]),
                                  **({"ValidityLastNewStartDate":random.choice(["2030-07-31","2023-07-31"])} if random.random()<0.5 else {})}]
        if extra: d.update(extra)
        seq+=1; dels.append(d); return d
    seq=1
    if tl:
        ld(1,31,"ZPROG001",extra={"HRSRecords":[{"HRSType":random.choice(["HRS","hrs"]),"HRSCode":2,"HRSAmount":random.choice([1100,1200,1400,1600,1800])}]})
        ld(5,31,random.choice(["60358294","60358300"]),"1468")
        ld(3,31,random.choice(["ZTLOS001","ZTLOS002"]),extra={"LARSProgrammeFunding":[{"PFTlevelFundingBand":random.choice(["9","8","7","6","5","8 uplifted","7 uplifted","6 uplifted","X"]),
             "PFTlevelPCW":random.choice([1.0,1.29,1.58,1.73]),"PFProgrammeCode":random.choice([52,56,60]),"PFEffectiveFrom":"2020-08-01",**({"PFEffectiveTo":random.choice(["2030-07-31","2026-07-31"])} if random.random()<0.5 else {})}]})
    elif trans:
        ld(1,30,"ZTPR0001"); ld(5,30,random.choice(["ZTPR0001","ZTPR0002","ZTPR0005","ZTPR0010","ZTPR0099"]))
    else:
        ld(5)
    for i in range(random.randint(0,2)): ld(random.choice([4,4,3]))
    lr["LearningDeliveries"]=dels
    json.dump({"provider":prov,"postcode_specialist_resources":pcs,"learner":lr},open(f"{D}/fz{n:03d}.json","w"))
print('ok')
