"""Independent reference implementation of the DfE "16 to 19 funding calculation for
2026 to 2027: technical specification v1.00", section 4 (pages 37-89), in Python.

Usage:  from dfe_ref import calculate;  out = calculate(case_dict)

OPA semantics modelled (spec section 2, pages 13-19):
  * three-valued logic plus two "no value" states: UNKNOWN (not provided) and
    UNCERTAIN (provided, but the conclusion cannot be determined).
  * and/or follow the truth tables of page 18; UNKNOWN takes precedence over
    UNCERTAIN when both are present (it may still become known).
  * "currently known" is true for a value AND for UNCERTAIN (an uncertain
    attribute has been determined to be uncertain); false only for UNKNOWN.
    The rulebase pairs "is currently known and is certain" on pages 59, 62, 81, 82
    and 87, which only makes sense under this reading.
  * "is certain": true for a value, false for UNCERTAIN, UNKNOWN for UNKNOWN.
  * rule tables: rows top to bottom, the first row whose condition is true wins;
    a row whose condition is UNKNOWN/UNCERTAIN stops the table with that state.
  * boolean rules ("X if ...") take the value of the condition (alternative
    conclusion = false).
  * aggregates (InstanceMinimum/Maximum, "the latest of all", "which is the greatest
    for all ..."): empty set -> UNCERTAIN; any member value UNKNOWN -> UNKNOWN.
  * InstanceValueIf: exactly one matching instance -> its value; none or more than
    one -> UNCERTAIN (Oracle function reference).
  * TemporalFromRange(start, end) uses an exclusive end date; ValueAt(d) picks the
    record whose range covers d.
See NOTES.md for every interpretive decision.
"""
from __future__ import annotations

import datetime as _dt
from functools import cached_property


# --------------------------------------------------------------------------- #
# Sentinels and three-valued helpers (page 17-19)                              #
# --------------------------------------------------------------------------- #
class _Sentinel:
    def __init__(self, name):
        self.name = name

    def __repr__(self):
        return self.name

    def __bool__(self):  # guard against accidental truth-testing
        raise TypeError("truth-testing a sentinel: " + self.name)


UNKNOWN = _Sentinel("UNKNOWN")
UNCERTAIN = _Sentinel("UNCERTAIN")
LATEST = _dt.date.max  # OPA Latest()


def is_s(v):
    return v is UNKNOWN or v is UNCERTAIN


def _worst(vals):
    """the sentinel that dominates among vals (UNKNOWN over UNCERTAIN), or None"""
    if any(v is UNKNOWN for v in vals):
        return UNKNOWN
    if any(v is UNCERTAIN for v in vals):
        return UNCERTAIN
    return None


def AND(*xs):
    """page 18: false dominates; then unknown/uncertain; else true. Args may be thunks."""
    seen = []
    for x in xs:
        v = x() if callable(x) else x
        if v is False:
            return False
        seen.append(v)
    w = _worst(seen)
    return w if w is not None else True


def OR(*xs):
    seen = []
    for x in xs:
        v = x() if callable(x) else x
        if v is True:
            return True
        seen.append(v)
    w = _worst(seen)
    return w if w is not None else False


def NOT(v):
    return v if is_s(v) else (not v)


def known(v):
    """'is currently known' / 'is known' (page 18): uncertain counts as known"""
    return v is not UNKNOWN


def unknown(v):
    return v is UNKNOWN


def certain(v):
    if v is UNKNOWN:
        return UNKNOWN
    return v is not UNCERTAIN


def cmp(a, op, b):
    w = _worst([a, b])
    if w is not None:
        return w
    if op == "=":
        return a == b
    if op == "<>":
        return a != b
    if op == "<":
        return a < b
    if op == "<=":
        return a <= b
    if op == ">":
        return a > b
    if op == ">=":
        return a >= b
    raise ValueError(op)


def in_(v, options):
    """'v = o1 or v = o2 or ...'"""
    if is_s(v):
        return v
    return v in options


def upper(v):
    return v if is_s(v) else str(v).upper()


def contains(text, sub):
    """OPA 'contains' -- treated as case-sensitive (see NOTES.md)"""
    if is_s(text):
        return text
    return sub in text


def arith(fn, *args):
    w = _worst(list(args))
    if w is not None:
        return w
    return fn(*args)


def table(*rows):
    """OPA rule table (page 17): rows of (condition-thunk, value-thunk); the last row
    is usually ('otherwise', value)."""
    for cond, val in rows:
        c = True if cond == "otherwise" else (cond() if callable(cond) else cond)
        if c is True:
            return val() if callable(val) else val
        if c is False:
            continue
        return c  # UNKNOWN or UNCERTAIN stops the table
    return UNCERTAIN  # no otherwise row (never reached in this rulebase)


# --- collections: list of (item, membership truth value) ------------------- #
def exists(coll, pred):
    """'for at least one of ...'"""
    return OR(*[(lambda i=i, m=m: AND(m, lambda: pred(i))) for i, m in coll])


def forall(coll, pred):
    """'for all of ...'"""
    return AND(*[(lambda i=i, m=m: OR(NOT(m), lambda: pred(i))) for i, m in coll])


def members(coll, cond=None):
    """returns (list of member items, sentinel or None)"""
    out, bad = [], []
    for i, m in coll:
        c = m
        if c is True and cond is not None:
            c = cond(i)
        if c is True:
            out.append(i)
        elif c is not False:
            bad.append(c)
    return out, _worst(bad)


def count(coll):
    """InstanceCount / 'the number of ...'"""
    ms, w = members(coll)
    return w if w is not None else len(ms)


def agg_max(coll, valfn, cond=None, fn=max):
    """InstanceMaximum(If) / 'which is the latest/greatest for all of ...'"""
    ms, w = members(coll, cond)
    if w is not None:
        return w
    if not ms:
        return UNCERTAIN
    vals = [valfn(i) for i in ms]
    w = _worst(vals)
    if w is not None:
        return w
    return fn(vals)


def agg_min(coll, valfn, cond=None):
    return agg_max(coll, valfn, cond, fn=min)


def ivif(coll, valfn, cond):
    """InstanceValueIf(entity, attribute, condition)"""
    ms, w = members(coll, cond)
    if w is not None:
        return w
    if len(ms) != 1:
        return UNCERTAIN
    return valfn(ms[0])


def temporal_value_at(records, d):
    """ValueAt(d, TemporalFromRange(records, from, applicable to, value)).
    records: list of (from, applicable_to, value). End date exclusive."""
    hits = []
    for frm, to, val in records:
        if is_s(frm) or is_s(to):
            continue
        if frm <= d < to:
            hits.append((frm, val))
    if not hits:
        return UNCERTAIN
    hits.sort(key=lambda h: h[0])
    return hits[-1][1]  # overlapping ranges: the latest-starting record wins (NOTES.md)


# --- date helpers (OPA functions) ------------------------------------------ #
def day_diff_inclusive(a, b):
    return arith(lambda x, y: (y - x).days + 1, a, b)


def month_difference(a, b):
    """MonthDifference: whole months from a to b"""
    def f(x, y):
        sign = 1
        if y < x:
            x, y, sign = y, x, -1
        m = (y.year - x.year) * 12 + (y.month - x.month)
        if y.day < x.day:
            m -= 1
        return sign * m
    return arith(f, a, b)


def years_between(a, b):
    """'the number of years between' -- whole years"""
    def f(x, y):
        sign = 1
        if y < x:
            x, y, sign = y, x, -1
        n = y.year - x.year
        if (y.month, y.day) < (x.month, x.day):
            n -= 1
        return sign * n
    return arith(f, a, b)


def add_days(d, n):
    return arith(lambda x: x + _dt.timedelta(days=n), d)


def extract_month(d):
    return arith(lambda x: x.month, d)


# --------------------------------------------------------------------------- #
# Parameters (pages 68-69)                                                    #
# --------------------------------------------------------------------------- #
FIRST_DAY = _dt.date(2026, 8, 1)
LAST_DAY = _dt.date(2027, 7, 31)
LAST_DAY_PREV = _dt.date(2026, 7, 31)
JUNE_1 = _dt.date(2027, 6, 1)
TWO_YEAR_FIRST_YEAR_END = _dt.date(2027, 6, 30)

NR_TL9, TH_TL9 = 15126, 1730
NR_TL8U, TH_TL8U = 14564, 1580
NR_TL8, TH_TL8 = 13870, 1580
NR_TL7U, TH_TL7U = 13242, 1380
NR_TL7, TH_TL7 = 12612, 1380
NR_TL6U, TH_TL6U = 11484, 1180
NR_TL6, TH_TL6 = 10936, 1180
NR_TL5, TH_TL5 = 10512, 580
FUNDED_HOURS_PER_FTE = 640
NR_FT, TH_FT = 5256, 580
NR_PT4, TH_PT4 = 4348, 485
NR_PT3, TH_PT3 = 3536, 385
NR_PT2, TH_PT2 = 2796, 300
NR_PT1_FTE, TH_PT1 = 5256, 0
NATIONAL_PCW_ZTPR = {  # pages 68-69
    "ZTPR0001": 1.58, "ZTPR0002": 1.04, "ZTPR0004": 1.19, "ZTPR0005": 1.73,
    "ZTPR0006": 1.21, "ZTPR0007": 1.48, "ZTPR0008": 1.73, "ZTPR0010": 1.21,
    "ZTPR0011": 1.0, "ZTPR0012": 1.0,
}

# Rate band texts (pages 50-51)
RB_TL9 = "1730 hours (T level Band 9)"
RB_TL8U = "1580 hours (T level Band 8 uplifted)"
RB_TL8 = "1580 hours (T level Band 8)"
RB_TL7U = "1380 hours (T level Band 7 uplifted)"
RB_TL7 = "1380 hours (T level Band 7)"
RB_TL6U = "1180 hours (T level Band 6 uplifted)"
RB_TL6 = "1180 hours (T level Band 6)"
RB_TL5 = "580 to 1179 hours (T level Band 5)"
RB_5 = "580+ hours (Band 5)"
RB_4A = "485+ hours (Band 4a)"
RB_4B = "485 to 579 hours (Band 4b)"
RB_3 = "385 to 484 hours (Band 3)"
RB_2 = "300 to 384 hours (Band 2)"
RB_1 = "Up to 299 hours (Band 1)"
RB_NONE = "None"
# the list used by the condition of funding rules (pages 41-47)
COF_BANDS = [RB_TL9, RB_TL8U, RB_TL8, RB_TL7U, RB_TL7, RB_TL6U, RB_TL6, RB_TL5, RB_5, RB_4A]

FL_1416 = "14-16 Direct Funded Students"
FL_HNS = "16-19 High Needs Students"
FL_1619 = "16-19 Students (excluding High Needs Students)"
FL_EHCP = "19-24 Students with an EHCP"
FL_19PLUS = "19+ Continuing Students (excluding EHCP)"
FL_UNKNOWN = "Unknown"

GRADES_C_PLUS = ["A*", "A", "B", "C", "9", "8", "7", "6", "5", "4"]
GRADES_D = ["D", "3"]
GRADES_BELOW_D = ["E", "F", "G", "U", "X", "NONE", "2", "1"]
GRADES_D_OR_BELOW = ["D", "E", "F", "G", "U", "X", "NONE", "3", "2", "1"]

KINGS_TRUST_REFS = ["60023995", "60027307", "60027629", "60032121", "60032868", "60033344"]
CORE_MATHS_REFS = ["60147830", "60147829", "60148573", "60149450"]

# --------------------------------------------------------------------------- #
# Annex A (Programme cost weightings by SSA) -- page 60 embeds the full table  #
# as a rule table; it matches gov.uk "16 to 19 funding: 2025 to 2026 rates and #
# formula", Annex A table A1, unchanged for 2026 to 2027 (gov.uk "16 to 19     #
# funding: information for 2026 to 2027": no planned changes to PCWs).         #
# https://www.gov.uk/government/publications/funding-rates-and-formula/16-to-19-funding-2025-to-2026-rates-and-formula
# --------------------------------------------------------------------------- #
SSA_SPECIALIST_CANDIDATES = [3.1, 3.2, 3.3]      # 2.09 with specialist resources
SSA_WEIGHTS = [                                  # rows of page 60 after the 2.09 rows
    (1.73, [4.1, 4.2, 4.3, 5.2]),
    (1.58, [3.1, 3.2, 3.3, 3.4]),
    (1.44, [7.4, 6.1]),
    (1.29, [5.1, 5.3, 7.1, 7.3, 9.1, 9.2, 13.1, 13.2]),
]
# Annex B (area cost uplift by region) is not needed: the provider's area cost factor
# is an input (AreaCostFactor1618, page 21).


# --------------------------------------------------------------------------- #
# Input access                                                                #
# --------------------------------------------------------------------------- #
def _date(v):
    if v is None:
        return UNKNOWN
    if isinstance(v, _dt.date):
        return v
    return _dt.date.fromisoformat(str(v)[:10])


def g(d, key, kind=None):
    """value of an input attribute, UNKNOWN when absent (or JSON null)"""
    if d is None or key not in d or d[key] is None:
        return UNKNOWN
    v = d[key]
    if kind == "date":
        return _date(v)
    if kind == "text":
        return str(v)
    return v


class FAM:
    def __init__(self, d):
        self.type = g(d, "LearnDelFAMType", "text")
        self.code = g(d, "LearnDelFAMCode", "text")


class Validity:
    def __init__(self, d):
        self.category = g(d, "ValidityCategory", "text")
        self.start = g(d, "ValidityStartDate", "date")
        self.last_new_start = g(d, "ValidityLastNewStartDate", "date")

    @property
    def upper_category(self):  # page 48
        return upper(self.category)


class ProgFunding:
    def __init__(self, d, ld_raw):
        self.band = g(d, "PFTlevelFundingBand", "text")
        self.pcw = g(d, "PFTlevelPCW")
        self.eff_from = g(d, "PFEffectiveFrom", "date")
        self.eff_to = g(d, "PFEffectiveTo", "date")
        # PFProgrammeCode is an attribute of the LARS programme funding (page 25);
        # the schema allows it on the delivery: accept both, prefer the record.
        pc = g(d, "PFProgrammeCode")
        self.programme_code = pc if pc is not UNKNOWN else g(ld_raw, "PFProgrammeCode")

    @property
    def applicable_to(self):  # page 81
        return table(
            (lambda: AND(known(self.eff_to), certain(self.eff_to)), lambda: add_days(self.eff_to, 1)),
            ("otherwise", LATEST),
        )


class HRS:
    def __init__(self, d):
        self.type = g(d, "HRSType", "text")
        self.code = g(d, "HRSCode")
        self.amount = g(d, "HRSAmount")

    @property
    def is_tlevel_delivery_hours(self):  # page 89
        return AND(cmp(upper(self.type), "=", "HRS"), cmp(self.code, "=", 2))


class LarsCategory:
    def __init__(self, d):
        self.ref = g(d, "LearnDelCatRef")
        self.date_from = g(d, "LearnDelCatDateFrom", "date")
        self.date_to = g(d, "LearnDelCatDateTo", "date")


class PostcodeSR:
    """Postcode_Specialist_Resource_RefData (global, page 24)"""

    def __init__(self, d):
        self.postcode = g(d, "PostcodeSpecResPostcode", "text")
        self.sr = g(d, "PostcodeSpecResSpecialistResources", "text")
        self.eff_from = g(d, "PostcodeSpecResEffectiveFrom", "date")
        self.eff_to = g(d, "PostcodeSpecResEffectiveTo", "date")

    @property
    def applicable_to(self):  # page 62
        return table(
            (lambda: AND(known(self.eff_to), certain(self.eff_to)), lambda: add_days(self.eff_to, 1)),
            ("otherwise", LATEST),
        )

    @property
    def effective_at_first_day(self):  # page 62 (both membership rules)
        return AND(cmp(FIRST_DAY, ">=", self.eff_from), cmp(FIRST_DAY, "<=", self.applicable_to))


def _all(xs):
    return [(x, True) for x in xs]


# --------------------------------------------------------------------------- #
# Learning delivery                                                           #
# --------------------------------------------------------------------------- #
class LD:
    def __init__(self, raw, L):
        self.raw = raw
        self.L = L
        self.learn_aim_ref = g(raw, "LearnAimRef", "text")
        self.aim_type = g(raw, "AimType")
        self.seq = g(raw, "AimSeqNumber")
        self.fund_model = g(raw, "FundModel")
        if self.fund_model is UNKNOWN:
            self.fund_model = g(raw, "Fundmodel")
        self.prog_type = g(raw, "ProgType")
        self.start = g(raw, "LearnStartDate", "date")
        self.plan_end = g(raw, "LearnPlanEndDate", "date")
        self.act_end = g(raw, "LearnActEndDate", "date")
        self.comp_status = g(raw, "CompStatus")
        self.withdraw_reason = g(raw, "WithdrawReason")
        self.title = g(raw, "LearnAimRefTitle", "text")
        self.ref_type = g(raw, "LearnAimRefType", "text")
        self.award_org = g(raw, "AwardOrgCode", "text")
        self.cof_type = g(raw, "EFACOFType")
        self.ssa2 = g(raw, "SectorSubjectAreaTier2")
        self.del_loc_postcode = g(raw, "DelLocPostcode", "text")
        self.fams = [FAM(f) for f in raw.get("FAMs") or []]
        self.validities = [Validity(v) for v in raw.get("LARSValidities") or []]
        self.prog_funding = [ProgFunding(p, raw) for p in raw.get("LARSProgrammeFunding") or []]
        self.hrs = [HRS(h) for h in raw.get("HRSRecords") or []]
        cats = raw.get("LARSCategories")
        if cats is None and "LearnDelCatRef" in raw:
            cats = [{k: raw[k] for k in ("LearnDelCatRef", "LearnDelCatDateFrom", "LearnDelCatDateTo") if k in raw}]
        self.categories = [LarsCategory(c) for c in cats or []]

    # ---- membership of learner relationships ----
    @cached_property
    def m_esfa(self):  # page 76
        return cmp(self.fund_model, "=", 25)

    @cached_property
    def is_core_aim(self):  # page 75
        return cmp(self.aim_type, "=", 5)

    @cached_property
    def m_core(self):  # page 75
        return AND(self.m_esfa, self.is_core_aim)

    # ---- page 38 ----
    @cached_property
    def is_direct_funded(self):
        return exists(_all(self.fams), lambda f: AND(cmp(upper(f.type), "=", "LDM"), cmp(f.code, "=", "320")))

    # ---- page 40: King's Trust TEAM ----
    def _validity_ok(self, v, category):
        return AND(
            cmp(v.upper_category, "=", category),
            known(v.start),
            lambda: cmp(self.start, ">=", v.start),
            lambda: OR(unknown(v.last_new_start),
                       lambda: AND(known(v.last_new_start), lambda: cmp(self.start, "<=", v.last_new_start))),
        )

    @cached_property
    def is_kings_trust_team(self):
        return AND(
            self.is_core_aim,
            lambda: exists(_all(self.fams), lambda f: AND(cmp(upper(f.type), "=", "LDM"), cmp(f.code, "=", "331"))),
            lambda: in_(self.learn_aim_ref, KINGS_TRUST_REFS),
            lambda: exists(_all(self.validities), lambda v: self._validity_ok(v, "1619_EFA")),
        )

    # ---- page 48 ----
    @cached_property
    def n_lars_validity(self):
        stage1 = len(self.validities)
        return table((lambda: known(stage1), stage1), ("otherwise", 0))

    # ---- pages 41-44: recognised GCSE qualification ----
    def _recognised(self, subj):
        L = self.L
        if subj == "E":
            fam, has_d, cat = L.ecf, L.has_eng_d, "EFACONFUNDENGLISH"
        else:
            fam, has_d, cat = L.mcf, L.has_maths_d, "EFACONFUNDMATHS"
        band_in_list = lambda: in_(L.rate_band, COF_BANDS)
        not_d_or_band_out = lambda: OR(NOT(has_d), lambda: AND(has_d, lambda: NOT(band_in_list())))
        validity = lambda: AND(cmp(self.n_lars_validity, ">", 0),
                               lambda: exists(_all(self.validities), lambda v: self._validity_ok(v, cat)))
        a = lambda: AND(known(fam), lambda: cmp(fam, "=", 4))
        b = lambda: AND(self.is_valid_start_cof, not_d_or_band_out, validity)
        c = lambda: AND(self.is_valid_start_cof, has_d, band_in_list,
                        lambda: cmp(self.cof_type, "=", 1), validity)
        d = lambda: AND(self.is_valid_start_cof, not_d_or_band_out, lambda: self.is_kings_trust_team)
        return OR(a, b, c, d)

    @cached_property
    def is_recognised_english(self):
        return self._recognised("E")

    @cached_property
    def is_recognised_maths(self):
        return self._recognised("M")

    # ---- page 54: academic flag ----
    @cached_property
    def upper_award_org(self):
        return upper(self.award_org)

    @cached_property
    def is_academic(self):
        t = self.ref_type
        return table(
            (lambda: self.is_tl_prog_aim, False),
            (lambda: self.is_tl_transition_prog_aim, False),
            (lambda: unknown(t), False),
            (lambda: self.is_gs_or_ct, False),
            (lambda: in_(t, ["0001", "0002"]), True),                      # A level
            (lambda: in_(t, ["0003", "2999"]), True),                      # GCSE
            (lambda: OR(lambda: AND(cmp(t, "=", "0016"), known(self.upper_award_org),
                                    lambda: cmp(self.upper_award_org, "=", "IB")),
                        lambda: cmp(t, "=", "1401")), True),                # IB
            (lambda: AND(cmp(t, "=", "0016"), known(self.learn_aim_ref),
                         lambda: in_(self.learn_aim_ref, CORE_MATHS_REFS)), True),  # core maths
            (lambda: in_(t, ["1446", "1447"]), True),                      # Pre-U
            (lambda: cmp(t, "=", "1420"), True),                           # FSMQ
            (lambda: in_(t, ["1440", "1460"]), True),                      # Access to HE
            (lambda: cmp(t, "=", "1469"), True),                           # AAQ
            ("otherwise", False),
        )

    # ---- page 55 ----
    @cached_property
    def is_gs_or_ct(self):
        return AND(known(self.title),
                   lambda: OR(contains(self.title, "General Studies"), contains(self.title, "Critical Thinking")),
                   known(self.ref_type),
                   lambda: in_(self.ref_type, ["0001", "0002"]))

    @cached_property
    def is_psychology(self):
        return AND(known(self.title),
                   lambda: OR(contains(self.title, "Psychology"), contains(self.title, "psychology")))

    # ---- page 59 ----
    @cached_property
    def is_a_level_uplift(self):
        return exists(_all(self.categories),
                      lambda c: AND(cmp(c.ref, "=", 64), cmp(self.fund_model, "=", 25)))

    # ---- page 60: learning delivery's programme weighting ----
    @cached_property
    def programme_weighting(self):
        L, s = self.L, self.ssa2
        spec = lambda: in_(s, SSA_SPECIALIST_CANDIDATES)
        rows = [
            (lambda: L.low_pcw_criteria, 1.15),
            (lambda: L.is_academic_programme, 1),
            (lambda: unknown(s), 1),
            (lambda: AND(spec, lambda: cmp(self.pc_sr_count, ">", 0),
                         lambda: exists(self.pc_sr_for_postcode, lambda r: cmp(r.sr, "=", "Y"))), 2.09),
            (lambda: AND(spec, lambda: cmp(self.pc_sr_count, "=", 0), lambda: L.provider_sr), 2.09),
        ]
        for w, ssas in SSA_WEIGHTS:
            rows.append((lambda ssas=ssas: in_(s, ssas), w))
        rows.append(("otherwise", 1))
        return table(*rows)

    # ---- page 62: postcode specialist resources ----
    @cached_property
    def pc_sr_for_postcode(self):
        return [(r, AND(cmp(r.postcode, "=", self.del_loc_postcode), lambda r=r: r.effective_at_first_day))
                for r in self.L.postcode_sr]

    @cached_property
    def pc_sr_for_applicable_start(self):
        # literal reading: no postcode condition (NOTES.md)
        return [(r, r.effective_at_first_day) for r in self.L.postcode_sr]

    @cached_property
    def pc_sr_flags_value_at_first_day(self):
        """the learning delivery's applicable postcode specialist resource flag (page 62; unused)"""
        ms, w = members(self.pc_sr_for_postcode)
        if w is not None:
            return w
        return temporal_value_at([(r.eff_from, r.applicable_to, r.sr) for r in ms], FIRST_DAY)

    @cached_property
    def pc_sr_count(self):
        stage1 = count(self.pc_sr_for_applicable_start)
        return table((lambda: AND(known(stage1), certain(stage1)), stage1), ("otherwise", 0))

    # ---- pages 72-74: dates ----
    @cached_property
    def planned_duration(self):  # page 72
        return month_difference(self.start, self.plan_end)

    @cached_property
    def adjusted_act_end(self):  # page 71
        return table((lambda: known(self.act_end), self.act_end), ("otherwise", self.plan_end))

    @cached_property
    def plan_end_this_year(self):  # page 74
        return table(
            (lambda: cmp(self.start, ">", LAST_DAY), UNCERTAIN),
            (lambda: cmp(self.plan_end, ">", LAST_DAY), LAST_DAY),
            (lambda: known(self.plan_end), self.plan_end),
            ("otherwise", UNCERTAIN),
        )

    @cached_property
    def planned_days(self):  # page 73
        pe = self.plan_end_this_year
        return table(
            (lambda: AND(known(self.start), certain(pe), lambda: cmp(pe, ">=", self.start)),
             lambda: day_diff_inclusive(self.start, pe)),
            ("otherwise", 0),
        )

    @cached_property
    def actual_days(self):  # page 73
        ae = self.adjusted_act_end
        return table(
            (lambda: AND(certain(self.start), certain(ae), lambda: cmp(ae, ">=", self.start)),
             lambda: day_diff_inclusive(self.start, ae)),
            ("otherwise", 0),
        )

    @cached_property
    def qualifying_period(self):  # page 73
        return table(
            (lambda: cmp(self.planned_days, ">=", 168), 42),
            (lambda: cmp(self.planned_days, ">=", 14), 14),
            ("otherwise", 0),
        )

    @cached_property
    def is_start(self):  # page 73
        return AND(cmp(self.qualifying_period, ">", 0),
                   lambda: cmp(self.actual_days, ">=", self.qualifying_period))

    @cached_property
    def is_valid_start_cof(self):  # page 73
        return self.is_start

    # ---- T levels (pages 77-79, 81, 87, 89) ----
    @cached_property
    def is_tl_prog_aim(self):  # page 77
        return AND(known(self.prog_type), lambda: cmp(self.prog_type, "=", 31), lambda: cmp(self.aim_type, "=", 1))

    @cached_property
    def is_tl_transition_prog_aim(self):  # page 79
        return AND(known(self.prog_type), lambda: cmp(self.prog_type, "=", 30), lambda: cmp(self.aim_type, "=", 1))

    @cached_property
    def is_tl_os_aim(self):  # page 87
        return AND(cmp(self.prog_type, "=", 31), lambda: contains(self.learn_aim_ref, "ZTLOS"))

    @cached_property
    def tl_hours_amount(self):  # page 89
        return ivif(_all(self.hrs), lambda h: h.amount, lambda h: h.is_tlevel_delivery_hours)

    @cached_property
    def applicable_tl_funding_band(self):  # page 81
        return temporal_value_at([(p.eff_from, p.applicable_to, p.band) for p in self.prog_funding], FIRST_DAY)

    @cached_property
    def applicable_tl_pcw(self):  # page 81
        return temporal_value_at([(p.eff_from, p.applicable_to, p.pcw) for p in self.prog_funding], FIRST_DAY)


# --------------------------------------------------------------------------- #
# Learner                                                                     #
# --------------------------------------------------------------------------- #
class Learner:
    def __init__(self, case):
        self.case = case
        self.prov = case.get("provider") or {}
        self.raw = case.get("learner") or {}
        r = self.raw
        self.learn_ref = g(r, "LearnRefNumber", "text")
        self.dob = g(r, "DateOfBirth", "date")
        self.eng_grade = g(r, "EngGrade", "text")
        self.math_grade = g(r, "MathGrade", "text")
        self.ecf = g(r, "LrnFAM_ECF")
        self.edf1 = g(r, "LrnFAM_EDF1")
        self.edf2 = g(r, "LrnFAM_EDF2")
        self.ehc = g(r, "LrnFAM_EHC")
        self.hns = g(r, "LrnFAM_HNS")
        self.mcf = g(r, "LrnFAM_MCF")
        self.nlm1 = g(r, "LrnFAM_NLM1")
        self.nlm2 = g(r, "LrnFAM_NLM2")
        self.emh = g(r, "LrnFAM_EMH")
        self.mmh = g(r, "LrnFAM_MMH")
        self.plan_eep = g(r, "PlanEEPHours")
        self.plan_learn = g(r, "PlanLearnHours")
        self.postcode_uplift = g(r, "PostcodeDisadvantageUplift")
        self.lds = [LD(d, self) for d in r.get("LearningDeliveries") or []]
        self.postcode_sr = [PostcodeSR(p) for p in case.get("postcode_specialist_resources") or []]
        p = self.prov
        self.p_acf = g(p, "AreaCostFactor1618")
        self.p_em = g(p, "EnglishandMathsProportion")
        self.p_disadv = g(p, "DisadvantageProportion")
        self.p_large = g(p, "HistoricLargeProgrammeProportion")
        self.p_pw = g(p, "ProgrammeWeighting")
        self.p_ret = g(p, "RetentionFactor")
        self.provider_sr = g(p, "SpecialistResources")

    # ---- relationships ----
    @cached_property
    def all_lds(self):
        return _all(self.lds)

    @cached_property
    def esfa(self):  # page 76
        return [(d, d.m_esfa) for d in self.lds]

    @cached_property
    def core_aims(self):  # page 75
        return [(d, d.m_core) for d in self.lds]

    @cached_property
    def tl_prog_aims(self):  # page 77 (membership over ALL the learner's deliveries)
        return [(d, AND(d.is_tl_prog_aim, lambda: self.is_tlevel)) for d in self.lds]

    @cached_property
    def tl_transition_aims(self):  # page 79
        return [(d, d.is_tl_transition_prog_aim) for d in self.lds]

    @cached_property
    def os_aims(self):  # page 87
        return [(d, AND(d.m_esfa, d.is_tl_os_aim, lambda: self.is_tlevel)) for d in self.lds]

    @cached_property
    def continuing_os_aims(self):  # page 87
        return [(d, AND(d.m_esfa, d.is_tl_os_aim, lambda d=d: cmp(d.comp_status, "=", 1), lambda: self.is_tlevel))
                for d in self.lds]

    @cached_property
    def a_level_uplift_aims(self):  # page 59
        return [(d, d.is_a_level_uplift) for d in self.lds]

    # ---- page 37: source of funding ----
    @cached_property
    def source_of_funding(self):
        return table(
            (lambda: exists(self.esfa, lambda d: exists(_all(d.fams), lambda f: AND(
                cmp(upper(f.type), "=", "SOF"), cmp(f.code, "=", "107")))), "ESFA 16-19"),
            ("otherwise", "Other"),
        )

    # ---- pages 37-38: funding line type ----
    @cached_property
    def funding_line(self):
        sof = lambda: cmp(self.source_of_funding, "=", "ESFA 16-19")
        age = self.age
        return table(
            (lambda: AND(sof, lambda: OR(cmp(age, "=", 14), cmp(age, "=", 15)),
                         lambda: exists(self.esfa, lambda d: d.is_direct_funded)), FL_1416),
            (lambda: AND(sof, lambda: cmp(age, "<", 19), known(self.hns), lambda: cmp(self.hns, "=", 1)), FL_HNS),
            (lambda: AND(sof, lambda: cmp(age, "<", 19),
                         lambda: OR(lambda: AND(known(self.hns), lambda: cmp(self.hns, "<>", 1)),
                                    unknown(self.hns))), FL_1619),
            (lambda: AND(sof, lambda: cmp(age, ">=", 19), lambda: cmp(age, "<=", 24),
                         lambda: self.is_ehc), FL_EHCP),
            (lambda: AND(sof, lambda: cmp(age, ">=", 19)), FL_19PLUS),
            ("otherwise", FL_UNKNOWN),
        )

    # ---- page 38: on-programme funding ----
    @cached_property
    def base_programme_funding(self):
        return arith(lambda a, b, c: a * b * c, self.national_rate, self.hist_retention, self.hist_pw)

    @cached_property
    def on_programme_funding(self):
        return table(
            (lambda: AND(self.is_start, lambda: cmp(self.funding_line, "<>", FL_1416)),
             lambda: arith(lambda b, d, l, e, a: b * (1 + d) * (1 + l) * (1 + e) * a,
                           self.base_programme_funding, self.hist_disadv, self.large_prog_prop,
                           self.hist_em_prop, self.hist_acf)),
            ("otherwise", 0),
        )

    # ---- pages 39-44 / 48: condition of funding attributes ----
    @cached_property
    def upper_eng(self):  # page 48
        return upper(self.eng_grade)

    @cached_property
    def upper_math(self):
        return upper(self.math_grade)

    @cached_property
    def has_eng_c(self):  # page 39
        return AND(known(self.upper_eng),
                   lambda: OR(in_(self.upper_eng, GRADES_C_PLUS),
                              lambda: AND(known(self.ecf), lambda: cmp(self.ecf, "=", 3))))

    @cached_property
    def has_maths_c(self):
        return AND(known(self.upper_math),
                   lambda: OR(in_(self.upper_math, GRADES_C_PLUS),
                              lambda: AND(known(self.mcf), lambda: cmp(self.mcf, "=", 3))))

    @cached_property
    def has_eng_d(self):  # page 40
        return AND(known(self.upper_eng), lambda: in_(self.upper_eng, GRADES_D))

    @cached_property
    def has_maths_d(self):
        return AND(known(self.upper_math), lambda: in_(self.upper_math, GRADES_D))

    @cached_property
    def has_eng_below_d(self):  # page 40
        return AND(known(self.upper_eng), lambda: in_(self.upper_eng, GRADES_BELOW_D))

    @cached_property
    def has_maths_below_d(self):  # page 41
        return AND(known(self.upper_math), lambda: in_(self.upper_math, GRADES_BELOW_D))

    @cached_property
    def eng_exemption(self):  # page 44
        return AND(known(self.ecf), lambda: in_(self.ecf, [1, 2]))

    @cached_property
    def maths_exemption(self):
        return AND(known(self.mcf), lambda: in_(self.mcf, [1, 2]))

    @cached_property
    def eng_fsl2(self):
        return AND(known(self.ecf), lambda: cmp(self.ecf, "=", 5))

    @cached_property
    def maths_fsl2(self):
        return AND(known(self.mcf), lambda: cmp(self.mcf, "=", 5))

    @cached_property
    def cof_min_hours_eng(self):
        return AND(known(self.emh), lambda: cmp(self.emh, "=", 1))

    @cached_property
    def cof_min_hours_maths(self):
        return AND(known(self.mmh), lambda: cmp(self.mmh, "=", 1))

    @cached_property
    def cof_not_required(self):  # page 44
        return OR(cmp(self.total_planned_hours, "<=", 149),
                  lambda: cmp(self.age, "<=", 15),
                  lambda: AND(self.latest_prog_is_tlevel,
                              lambda: cmp(self.latest_tl_prog_start, "<", _dt.date(2022, 8, 1))))

    # ---- pages 45-48: condition of funding status tables ----
    def _cof_status(self, subj):
        if subj == "E":
            has_c, has_d, below_d = self.has_eng_c, self.has_eng_d, self.has_eng_below_d
            exempt, fsl2, minh = self.eng_exemption, self.eng_fsl2, self.cof_min_hours_eng
            rec = lambda d: d.is_recognised_english
            S = ["Exempt from the GCSE English A*-C or 9 to 4 requirement",
                 "Has English, Studying English", "Has English, Not Studying English",
                 "Has English GCSE Grade D or Grade 3, Not studying GCSE English",
                 "Has English below GCSE grade D or grade 3, holds English FSL2 pass",
                 "Doesn't have English, Studying English", "Doesn't have English, Not Studying English"]
        else:
            has_c, has_d, below_d = self.has_maths_c, self.has_maths_d, self.has_maths_below_d
            exempt, fsl2, minh = self.maths_exemption, self.maths_fsl2, self.cof_min_hours_maths
            rec = lambda d: d.is_recognised_maths
            S = ["Exempt from the GCSE Mathematics A*-C or 9 to 4 requirement",
                 "Has Maths, Studying Maths", "Has Maths, Not Studying Maths",
                 "Has Maths GCSE Grade D or Grade 3, Not studying GCSE Maths",
                 "Has Maths below GCSE grade D or grade 3, holds Maths FSL2 pass",
                 "Doesn't have Maths, Studying Maths", "Doesn't have Maths, Not Studying Maths"]
        lds = self.all_lds  # "the learner's learning deliveries": all aims (page 37 scope note)
        return table(
            (lambda: self.cof_not_required, "Condition of Funding Does Not Apply"),
            (lambda: exempt, S[0]),
            (lambda: AND(has_c, lambda: exists(lds, rec)), S[1]),
            (lambda: has_c, S[2]),
            (lambda: AND(has_d, lambda: in_(self.rate_band, COF_BANDS),
                         lambda: OR(lambda: forall(lds, lambda d: NOT(rec(d))),
                                    lambda: exists(lds, lambda d: AND(rec(d), NOT(minh))))), S[3]),
            (lambda: AND(below_d, fsl2), S[4]),
            (lambda: AND(NOT(has_c), lambda: exists(lds, lambda d: AND(rec(d), minh))), S[5]),
            (lambda: AND(NOT(has_c), lambda: OR(lambda: forall(lds, lambda d: NOT(rec(d))), NOT(minh))), S[6]),
            ("otherwise", ""),
        )

    @cached_property
    def cof_english(self):
        return self._cof_status("E")

    @cached_property
    def cof_maths(self):
        return self._cof_status("M")

    # ---- pages 49-52: rate band and national rate ----
    @cached_property
    def rate_band(self):
        tl, b, h = (lambda: self.is_tlevel), self.tl_funding_band, self.total_planned_hours
        band = lambda opts: in_(b, opts)
        return table(
            (lambda: AND(tl, lambda: band(["9"]), lambda: cmp(h, ">=", TH_TL9)), RB_TL9),
            (lambda: AND(tl, lambda: band(["8 uplifted"]), lambda: cmp(h, ">=", TH_TL8U)), RB_TL8U),
            (lambda: AND(tl, lambda: band(["9", "8"]), lambda: cmp(h, ">=", TH_TL8)), RB_TL8),
            (lambda: AND(tl, lambda: band(["8 uplifted", "7 uplifted"]), lambda: cmp(h, ">=", TH_TL7U)), RB_TL7U),
            (lambda: AND(tl, lambda: band(["9", "8", "7"]), lambda: cmp(h, ">=", TH_TL7)), RB_TL7),
            (lambda: AND(tl, lambda: band(["8 uplifted", "7 uplifted", "6 uplifted"]),
                         lambda: cmp(h, ">=", TH_TL6U)), RB_TL6U),
            (lambda: AND(tl, lambda: band(["9", "8", "7", "6"]), lambda: cmp(h, ">=", TH_TL6)), RB_TL6),
            (lambda: AND(tl, lambda: cmp(h, ">=", TH_TL5)), RB_TL5),
            (lambda: AND(cmp(h, ">=", TH_FT), lambda: OR(cmp(self.age, "<", 18), lambda: self.is_hns),
                         lambda: NOT(self.is_tlevel)), RB_5),
            (lambda: AND(cmp(h, ">=", TH_PT4), lambda: cmp(self.age, ">=", 18), lambda: NOT(self.is_hns),
                         lambda: NOT(self.is_tlevel)), RB_4A),
            (lambda: cmp(h, ">=", TH_PT4), RB_4B),
            (lambda: cmp(h, ">=", TH_PT3), RB_3),
            (lambda: cmp(h, ">=", TH_PT2), RB_2),
            (lambda: cmp(h, ">=", TH_PT1), RB_1),
            ("otherwise", RB_NONE),
        )

    @cached_property
    def is_hns(self):  # page 51
        return AND(known(self.hns), lambda: cmp(self.hns, "=", 1))

    @cached_property
    def is_ehc(self):  # page 51
        return AND(known(self.ehc), lambda: cmp(self.ehc, "=", 1))

    @cached_property
    def national_rate(self):  # page 52
        rb = self.rate_band
        r = lambda s: (lambda: cmp(rb, "=", s))
        return table(
            (r(RB_TL9), NR_TL9 / 2), (r(RB_TL8U), NR_TL8U / 2), (r(RB_TL8), NR_TL8 / 2),
            (r(RB_TL7U), NR_TL7U / 2), (r(RB_TL7), NR_TL7 / 2), (r(RB_TL6U), NR_TL6U / 2),
            (r(RB_TL6), NR_TL6 / 2), (r(RB_TL5), NR_TL5 / 2),
            (r(RB_5), NR_FT),
            (lambda: in_(rb, [RB_4A, RB_4B]), NR_PT4),
            (r(RB_3), NR_PT3), (r(RB_2), NR_PT2),
            (r(RB_1), lambda: arith(lambda f: NR_PT1_FTE * f, self.fte)),
            ("otherwise", 0),
        )

    # ---- page 53: total planned hours and FTE ----
    @cached_property
    def total_planned_hours(self):
        tl_row = lambda starter: (lambda: exists(self.esfa, lambda d: AND(
            self.latest_prog_is_tlevel, d.is_tl_prog_aim, lambda: known(d.tl_hours_amount),
            lambda: starter())))
        tl_value = lambda: ivif(self.tl_prog_aims, lambda d: d.tl_hours_amount,
                                lambda d: cmp(self.latest_tl_prog_seq, "=", d.seq))
        return table(
            (tl_row(lambda: NOT(self.tl_starter_2122)), tl_value),
            (tl_row(lambda: self.tl_starter_2122),
             lambda: arith(lambda a, b: a + b, tl_value(), self.tl_additional_hours)),
            (lambda: AND(known(self.plan_learn), known(self.plan_eep)),
             lambda: arith(lambda a, b: a + b, self.plan_learn, self.plan_eep)),
            (lambda: known(self.plan_learn), self.plan_learn),
            (lambda: known(self.plan_eep), self.plan_eep),
            ("otherwise", 0),
        )

    @cached_property
    def fte(self):
        return arith(lambda h: h / FUNDED_HOURS_PER_FTE, self.total_planned_hours)

    # ---- page 55: academic programme ----
    @cached_property
    def is_academic_programme(self):
        return table(
            (lambda: exists(self.esfa, lambda d: AND(cmp(d.seq, "=", self.core_aim_seq), lambda: d.is_academic)), True),
            ("otherwise", False),
        )

    # ---- pages 56-57: new retention status ----
    @cached_property
    def retent_new(self):
        comp_ok = lambda d: AND(known(d.comp_status), lambda: in_(d.comp_status, [1, 2, 6]))
        withdrawn_ok = lambda d: OR(
            lambda: AND(known(d.comp_status), lambda: cmp(d.comp_status, "=", 3), known(d.withdraw_reason),
                        lambda: in_(d.withdraw_reason, [2, 7, 47])),
            lambda: AND(known(d.comp_status), lambda: cmp(d.comp_status, "=", 3), known(d.withdraw_reason),
                        lambda: cmp(d.planned_duration, ">=", 18), lambda: cmp(d.start, ">=", FIRST_DAY),
                        lambda: cmp(d.act_end, ">=", TWO_YEAR_FIRST_YEAR_END)))
        acad = lambda: self.is_academic_programme
        core = lambda d: cmp(d.seq, "=", self.core_aim_seq)
        return table(
            (lambda: NOT(self.is_start), 0),
            (lambda: AND(acad, lambda: exists(self.esfa, lambda d: AND(d.is_academic, lambda: comp_ok(d)))), 1),
            (lambda: AND(acad, lambda: exists(self.esfa, lambda d: AND(d.is_academic, lambda: withdrawn_ok(d)))), 1),
            (lambda: AND(NOT(acad()), lambda: exists(self.esfa, lambda d: AND(core(d), lambda: comp_ok(d)))), 1),
            (lambda: AND(NOT(acad()), lambda: exists(self.esfa, lambda d: AND(core(d), lambda: withdrawn_ok(d)))), 1),
            ("otherwise", 0.5),
        )

    # ---- page 58 / 61 / 65 / 67: provider factors ----
    @cached_property
    def hist_retention(self):
        return table((lambda: known(self.p_ret), self.p_ret), ("otherwise", 0))

    @cached_property
    def hist_pw(self):
        return table((lambda: known(self.p_pw), self.p_pw), ("otherwise", 0))

    @cached_property
    def hist_acf(self):
        return table((lambda: known(self.p_acf), self.p_acf), ("otherwise", 0))

    @cached_property
    def large_prog_prop(self):
        return table((lambda: known(self.p_large), self.p_large), ("otherwise", 0))

    @cached_property
    def hist_disadv(self):
        return table((lambda: known(self.p_disadv), self.p_disadv), ("otherwise", 0))

    @cached_property
    def hist_em_prop(self):
        return table((lambda: known(self.p_em), self.p_em), ("otherwise", 0))

    # ---- pages 58-60: new programme weighting ----
    @cached_property
    def new_pw_stage1(self):  # page 58
        return table(
            (lambda: cmp(self.n_core, ">", 0),
             lambda: ivif(self.esfa, lambda d: d.programme_weighting, lambda d: cmp(d.seq, "=", self.core_aim_seq))),
            ("otherwise", 1),
        )

    @cached_property
    def new_pw(self):  # page 59
        return table(
            (lambda: self.latest_prog_is_tlevel, lambda: self.tl_pcw),
            (lambda: self.latest_prog_is_transition, lambda: self.national_transition_pcw),
            (lambda: AND(cmp(self.new_pw_stage1, "=", 1),
                         lambda: exists(self.esfa, lambda d: d.is_kings_trust_team)), 1.44),
            ("otherwise", lambda: self.new_pw_stage1),
        )

    @cached_property
    def count_a_level_uplift(self):  # page 59
        stage1 = count(self.a_level_uplift_aims)
        return table((lambda: AND(known(stage1), certain(stage1)), stage1), ("otherwise", 0))

    @cached_property
    def low_pcw_criteria(self):  # page 59
        return table(
            (lambda: AND(self.is_academic_programme, lambda: cmp(self.count_a_level_uplift, ">", 1)), True),
            (lambda: AND(NOT(self.is_academic_programme), lambda: exists(self.esfa, lambda d: AND(
                cmp(d.seq, "=", self.core_aim_seq),
                lambda: OR(cmp(d.ssa2, "=", 1.1), cmp(d.ssa2, "=", 1.2),
                           lambda: AND(cmp(d.ssa2, "=", 2.1), lambda: NOT(d.is_psychology)))))), True),
            ("otherwise", False),
        )

    # ---- page 63 ----
    @cached_property
    def latest_ld_start(self):
        return table((lambda: cmp(len(self.lds), ">", 0), lambda: agg_max(self.all_lds, lambda d: d.start)),
                     ("otherwise", UNCERTAIN))

    # ---- page 64: disadvantage ----
    @cached_property
    def block1(self):
        return table((lambda: known(self.postcode_uplift), self.postcode_uplift), ("otherwise", 1))

    @cached_property
    def no_eng_c_by_y11(self):
        return OR(lambda: AND(known(self.edf1), lambda: cmp(self.edf1, "=", 2)),
                  lambda: AND(known(self.edf2), lambda: cmp(self.edf2, "=", 2)))

    @cached_property
    def no_maths_c_by_y11(self):
        return OR(lambda: AND(known(self.edf1), lambda: cmp(self.edf1, "=", 1)),
                  lambda: AND(known(self.edf2), lambda: cmp(self.edf2, "=", 1)))

    @cached_property
    def block2(self):
        e, m = NOT(self.no_eng_c_by_y11), NOT(self.no_maths_c_by_y11)
        return table((lambda: AND(e, m), 0), (lambda: OR(e, m), 1), ("otherwise", 2))

    # ---- pages 66-67: English and maths instances ----
    @cached_property
    def eng_d_or_below(self):
        return AND(known(self.upper_eng), lambda: in_(self.upper_eng, GRADES_D_OR_BELOW),
                   lambda: OR(unknown(self.ecf), lambda: AND(known(self.ecf), lambda: cmp(self.ecf, "<>", 2),
                                                             lambda: cmp(self.ecf, "<>", 3))))

    @cached_property
    def maths_d_or_below(self):
        return AND(known(self.upper_math), lambda: in_(self.upper_math, GRADES_D_OR_BELOW),
                   lambda: OR(unknown(self.mcf), lambda: AND(known(self.mcf), lambda: cmp(self.mcf, "<>", 2),
                                                             lambda: cmp(self.mcf, "<>", 3))))

    @cached_property
    def eng_exempt_difficulty(self):
        return OR(unknown(self.ecf), lambda: AND(known(self.ecf), lambda: in_(self.ecf, [1, 4, 5])))

    @cached_property
    def maths_exempt_difficulty(self):
        return OR(unknown(self.mcf), lambda: AND(known(self.mcf), lambda: in_(self.mcf, [1, 4, 5])))

    @cached_property
    def has_eng_instance(self):
        return AND(self.eng_d_or_below, lambda: self.eng_exempt_difficulty,
                   lambda: cmp(upper(self.cof_english), "<>",
                               "HAS ENGLISH BELOW GCSE GRADE D OR GRADE 3, HOLDS ENGLISH FSL2 PASS"),
                   lambda: cmp(self.total_planned_hours, ">=", 150))

    @cached_property
    def has_maths_instance(self):
        return AND(self.maths_d_or_below, lambda: self.maths_exempt_difficulty,
                   lambda: cmp(upper(self.cof_maths), "<>",
                               "HAS MATHS BELOW GCSE GRADE D OR GRADE 3, HOLDS MATHS FSL2 PASS"),
                   lambda: cmp(self.total_planned_hours, ">=", 150))

    @cached_property
    def em_instances(self):
        return table((lambda: AND(self.has_eng_instance, self.has_maths_instance), 2),
                     (lambda: OR(self.has_eng_instance, self.has_maths_instance), 1),
                     ("otherwise", 0))

    # ---- pages 69-72: date rules ----
    @cached_property
    def is_summer_school(self):  # page 69
        return AND(cmp(self.age, "<=", 15), lambda: cmp(self.start_date, ">=", JUNE_1))

    @cached_property
    def is_start(self):  # page 69
        common = lambda: AND(NOT(self.is_summer_school), lambda: cmp(self.funding_line, "<>", FL_UNKNOWN),
                             lambda: cmp(self.qualifying_period, ">", 0),
                             lambda: cmp(self.actual_days, ">=", self.qualifying_period))
        return OR(
            lambda: AND(self.is_tlevel, common,
                        lambda: OR(NOT(self.tl_year3), lambda: AND(self.tl_year3, lambda: self.repeating_final_year))),
            lambda: AND(NOT(self.is_tlevel), common),
        )

    @cached_property
    def qualifying_period(self):  # page 70
        return table(
            (lambda: AND(cmp(self.total_planned_hours, ">=", TH_PT4), lambda: cmp(self.planned_days, ">=", 14)), 42),
            (lambda: cmp(self.planned_days, ">=", 168), 42),
            (lambda: cmp(self.planned_days, ">=", 14), 14),
            ("otherwise", 0),
        )

    @cached_property
    def planned_days(self):  # page 70
        s, e = self.start_this_year, self.plan_end_this_year
        return table((lambda: AND(certain(s), certain(e), lambda: cmp(e, ">=", s)),
                      lambda: day_diff_inclusive(s, e)), ("otherwise", 0))

    @cached_property
    def actual_days(self):  # page 70
        s, e = self.start_this_year, self.act_end_this_year
        return table((lambda: AND(certain(s), certain(e), lambda: cmp(e, ">=", s)),
                      lambda: day_diff_inclusive(s, e)), ("otherwise", 0))

    @cached_property
    def start_date(self):  # page 70
        return agg_min(self.esfa, lambda d: d.start)

    @cached_property
    def start_this_year(self):  # page 71
        return table(
            (lambda: AND(known(self.act_end_date), lambda: cmp(self.act_end_date, "<", FIRST_DAY)), UNCERTAIN),
            (lambda: cmp(self.start_date, "<", FIRST_DAY), FIRST_DAY),
            (lambda: cmp(self.start_date, "<=", LAST_DAY), lambda: self.start_date),
            ("otherwise", UNCERTAIN),
        )

    @cached_property
    def plan_end_date(self):  # page 71
        return agg_max(self.esfa, lambda d: d.plan_end)

    @cached_property
    def plan_end_this_year(self):  # page 71
        return table(
            (lambda: cmp(self.start_date, ">", LAST_DAY), UNCERTAIN),
            (lambda: cmp(self.plan_end_date, ">", LAST_DAY), LAST_DAY),
            (lambda: cmp(self.plan_end_date, ">=", FIRST_DAY), lambda: self.plan_end_date),
            ("otherwise", UNCERTAIN),
        )

    @cached_property
    def act_end_date(self):  # page 71
        return agg_max(self.esfa, lambda d: d.adjusted_act_end)

    @cached_property
    def act_end_this_year(self):  # page 72
        return table(
            (lambda: cmp(self.start_date, ">", LAST_DAY), UNCERTAIN),
            (lambda: AND(known(self.act_end_date), lambda: cmp(self.act_end_date, ">", LAST_DAY)), LAST_DAY),
            (lambda: AND(known(self.act_end_date), lambda: cmp(self.act_end_date, ">=", FIRST_DAY)),
             lambda: self.act_end_date),
            ("otherwise", UNCERTAIN),
        )

    @cached_property
    def payment_period(self):  # page 72
        m = extract_month(self.start_this_year)
        return table(
            (lambda: AND(self.is_start, lambda: cmp(m, "<=", 7)), lambda: arith(lambda x: x + 5, m)),
            (lambda: AND(self.is_start, lambda: cmp(m, ">=", 8)), lambda: arith(lambda x: x - 7, m)),
            ("otherwise", 0),
        )

    @cached_property
    def age(self):  # page 72
        return years_between(self.dob, _dt.date(FIRST_DAY.year, 8, 31))

    # ---- pages 75-76: core aim selection ----
    @cached_property
    def n_core(self):
        stage1 = count(self.core_aims)
        return table((lambda: known(stage1), stage1), ("otherwise", 0))

    @cached_property
    def latest_core_start(self):
        return table((lambda: cmp(self.n_core, ">", 0), lambda: agg_max(self.core_aims, lambda d: d.start)),
                     ("otherwise", UNCERTAIN))

    @cached_property
    def latest_tq_core_start(self):
        return table(
            (lambda: AND(cmp(self.n_core, ">", 0), lambda: self.is_tlevel),
             lambda: agg_max(self.core_aims, lambda d: d.start, cond=lambda d: cmp(d.ref_type, "=", "1468"))),
            ("otherwise", UNCERTAIN),
        )

    @cached_property
    def core_aim_seq(self):  # page 76
        return table(
            (lambda: AND(cmp(self.n_core, ">", 0), lambda: self.is_tlevel, lambda: certain(self.latest_tq_core_start)),
             lambda: agg_max(self.core_aims, lambda d: d.seq,
                             cond=lambda d: cmp(d.start, "=", self.latest_tq_core_start))),
            (lambda: cmp(self.n_core, ">", 0),
             lambda: agg_max(self.core_aims, lambda d: d.seq, cond=lambda d: cmp(d.start, "=", self.latest_core_start))),
            ("otherwise", 0),
        )

    # ---- page 77: T levels ----
    @cached_property
    def latest_core_is_tlevel(self):
        return exists(self.core_aims, lambda d: AND(known(d.prog_type), certain(d.prog_type),
                                                    lambda: cmp(d.prog_type, "=", 31),
                                                    lambda: cmp(d.start, "=", self.latest_core_start)))

    @cached_property
    def is_tlevel(self):
        return self.latest_core_is_tlevel

    @cached_property
    def latest_prog_is_tlevel(self):
        return self.latest_core_is_tlevel

    @cached_property
    def n_tl_prog(self):
        stage1 = count(self.tl_prog_aims)
        return table((lambda: known(stage1), stage1), ("otherwise", 0))

    @cached_property
    def latest_tl_prog_start(self):  # page 78
        return table((lambda: cmp(self.n_tl_prog, ">", 0), lambda: agg_max(self.tl_prog_aims, lambda d: d.start)),
                     ("otherwise", UNCERTAIN))

    @cached_property
    def latest_tl_prog_seq(self):  # page 78 (= the learner's latest programme aim sequence number)
        return table(
            (lambda: cmp(self.n_tl_prog, ">", 0),
             lambda: agg_max(self.tl_prog_aims, lambda d: d.seq,
                             cond=lambda d: cmp(d.start, "=", self.latest_tl_prog_start))),
            ("otherwise", 0),
        )

    @cached_property
    def tl_year3(self):  # page 79
        return AND(cmp(self.latest_tl_prog_start, "<", _dt.date(FIRST_DAY.year - 1, 8, 1)), lambda: self.is_tlevel)

    @cached_property
    def tl_starter_2122(self):  # page 79
        return AND(cmp(self.latest_tl_prog_start, "<=", _dt.date(2022, 7, 31)), lambda: self.is_tlevel)

    # ---- pages 79-80: transition programme aims ----
    @cached_property
    def n_transition(self):
        stage1 = count(self.tl_transition_aims)
        return table((lambda: known(stage1), stage1), ("otherwise", 0))

    @cached_property
    def latest_transition_start(self):
        return table((lambda: cmp(self.n_transition, ">", 0),
                      lambda: agg_max(self.tl_transition_aims, lambda d: d.start)), ("otherwise", UNCERTAIN))

    @cached_property
    def latest_transition_seq(self):
        return table((lambda: cmp(self.n_transition, ">", 0),
                      lambda: agg_max(self.tl_transition_aims, lambda d: d.seq,
                                      cond=lambda d: cmp(d.start, "=", self.latest_transition_start))),
                     ("otherwise", 0))

    @cached_property
    def latest_prog_is_transition(self):  # page 80
        return exists(self.esfa, lambda d: AND(cmp(d.seq, "=", self.core_aim_seq), known(d.prog_type),
                                               lambda: cmp(d.prog_type, "=", 30)))

    @cached_property
    def is_transition_student(self):  # page 80
        return self.latest_prog_is_transition

    # ---- page 81: T level funding band ----
    @cached_property
    def tl_funding_band_stage1(self):
        return ivif(self.esfa, lambda d: d.applicable_tl_funding_band, lambda d: cmp(d.seq, "=", self.latest_os_seq))

    @cached_property
    def tl_funding_band(self):
        s1 = self.tl_funding_band_stage1
        return table(
            (lambda: AND(known(s1), certain(s1),
                         lambda: in_(s1, ["9", "8", "7", "6", "5", "8 uplifted", "7 uplifted", "6 uplifted"])), s1),
            (lambda: self.is_tlevel, "5"),
            ("otherwise", "0"),
        )

    # ---- page 82: T level PCW ----
    @cached_property
    def tl_pcw_stage1(self):
        return ivif(self.esfa, lambda d: d.applicable_tl_pcw, lambda d: cmp(d.seq, "=", self.latest_os_seq))

    @cached_property
    def tl_pcw(self):
        pc_ok = lambda d: exists(_all(d.prog_funding), lambda p: OR(cmp(p.programme_code, "=", 52),
                                                                    cmp(p.programme_code, "=", 56)))
        os = lambda d: AND(cmp(d.seq, "=", self.latest_os_seq), known(d.learn_aim_ref))
        s1 = self.tl_pcw_stage1
        return table(
            (lambda: AND(self.is_tlevel, lambda: exists(self.esfa, lambda d: AND(
                os(d), lambda: cmp(d.pc_sr_count, ">", 0),
                lambda: exists(d.pc_sr_for_postcode, lambda r: cmp(r.sr, "=", "Y")),
                lambda: pc_ok(d)))), 2.09),
            (lambda: AND(self.is_tlevel, lambda: self.provider_sr, lambda: exists(self.esfa, lambda d: AND(
                os(d), lambda: cmp(d.pc_sr_count, "=", 0), lambda: pc_ok(d)))), 2.09),
            (lambda: AND(known(s1), certain(s1), lambda: cmp(s1, ">", 0)), s1),
            (lambda: self.is_tlevel, 1),
            ("otherwise", 0),
        )

    # ---- page 83 ----
    @cached_property
    def tl_additional_hours(self):
        return table((lambda: AND(known(self.tl_starter_2122), lambda: self.tl_starter_2122), 40), ("otherwise", 0))

    @cached_property
    def repeating_final_year(self):
        return AND(self.is_tlevel, lambda: OR(lambda: AND(known(self.nlm1), lambda: cmp(self.nlm1, "=", 22)),
                                              lambda: AND(known(self.nlm2), lambda: cmp(self.nlm2, "=", 22))))

    # ---- pages 84-86: national T level transition programme PCW ----
    @cached_property
    def national_transition_pcw(self):
        tp = lambda: self.latest_prog_is_transition
        core_ref = lambda d, ref: AND(cmp(d.seq, "=", self.core_aim_seq), known(d.learn_aim_ref),
                                      lambda: cmp(d.learn_aim_ref, "=", ref))
        rows = [
            (lambda: AND(tp, lambda: exists(self.esfa, lambda d: AND(
                core_ref(d, "ZTPR0001"), lambda: cmp(d.pc_sr_count, ">", 0),
                lambda: exists(d.pc_sr_for_postcode, lambda r: cmp(r.sr, "=", "Y"))))), 2.09),
            (lambda: AND(tp, lambda: self.provider_sr, lambda: exists(self.esfa, lambda d: AND(
                core_ref(d, "ZTPR0001"), lambda: cmp(d.pc_sr_count, "=", 0)))), 2.09),
        ]
        for ref, w in NATIONAL_PCW_ZTPR.items():
            rows.append((lambda ref=ref: AND(tp, lambda: exists(self.esfa, lambda d: core_ref(d, ref))), w))
        rows.append(("otherwise", 1))
        return table(*rows)

    # ---- pages 87-89: T level OS aims ----
    @cached_property
    def n_os(self):
        stage1 = count(self.os_aims)
        return table((lambda: AND(known(stage1), certain(stage1)), stage1), ("otherwise", 0))

    @cached_property
    def has_continuing_os(self):  # page 88
        return AND(cmp(self.n_os, ">", 0), lambda: exists(self.os_aims, lambda d: cmp(d.comp_status, "=", 1)))

    @cached_property
    def latest_os_seq(self):  # page 88
        def latest(coll):
            mx = agg_max(coll, lambda d: d.start)
            return agg_max(coll, lambda d: d.seq, cond=lambda d: cmp(d.start, "=", mx))
        return table(
            (lambda: AND(cmp(self.n_os, ">", 0), lambda: self.has_continuing_os), lambda: latest(self.continuing_os_aims)),
            (lambda: AND(cmp(self.n_os, ">", 0), lambda: NOT(self.has_continuing_os)), lambda: latest(self.os_aims)),
            ("otherwise", 0),
        )

    @cached_property
    def tq_learn_aim_ref(self):  # page 88
        return ivif(self.esfa, lambda d: d.learn_aim_ref,
                    lambda d: AND(self.latest_core_is_tlevel, lambda: cmp(d.seq, "=", self.core_aim_seq)))

    @cached_property
    def os_learn_aim_ref(self):  # page 89
        return ivif(self.esfa, lambda d: d.learn_aim_ref, lambda d: cmp(d.seq, "=", self.latest_os_seq))

    def _tl_prog_aim_value(self, fn):  # page 89
        return ivif(self.esfa, fn, lambda d: cmp(d.seq, "=", self.latest_tl_prog_seq))

    @cached_property
    def tl_prog_act_end(self):
        return self._tl_prog_aim_value(lambda d: d.act_end)

    @cached_property
    def tl_prog_plan_end(self):
        return self._tl_prog_aim_value(lambda d: d.plan_end)

    @cached_property
    def tl_prog_start(self):
        return self._tl_prog_aim_value(lambda d: d.start)


# --------------------------------------------------------------------------- #
# Output                                                                      #
# --------------------------------------------------------------------------- #
def _out(v):
    if is_s(v):
        return None
    if isinstance(v, _dt.date):
        return v.isoformat()
    return v


def _state(v):
    """for intermediates: keep the distinction unknown/uncertain visible"""
    if v is UNKNOWN:
        return "<unknown>"
    if v is UNCERTAIN:
        return "<uncertain>"
    return _out(v)


def calculate(case: dict) -> dict:
    """Learner outputs of pages 34-36 (+ '_intermediate')."""
    L = Learner(case)
    out = {
        "LearnRefNumber": L.learn_ref,
        "AcadMonthPayment": L.payment_period,
        "AcadProg": L.is_academic_programme,
        "ActualDaysILCurrYear": L.actual_days,
        "AreaCostFact1618Hist": L.hist_acf,
        "Block1DisadvUpliftNew": L.block1,
        "Block2DisadvElementsNew": L.block2,
        "ConditionOfFundingEnglish": L.cof_english,
        "ConditionOfFundingMaths": L.cof_maths,
        "CoreAimSeqNumber": L.core_aim_seq,
        "ProgAimSeqNumber": L.latest_tl_prog_seq,
        "FullTimeEquiv": L.fte,
        "FundLine": L.funding_line,
        "LearnerActEndDate": L.act_end_date,
        "LearnerPlanEndDate": L.plan_end_date,
        "LearnerStartDate": L.start_date,
        "NatRate": L.national_rate,
        "OnProgPayment": L.on_programme_funding,
        "PlannedDaysILCurrYear": L.planned_days,
        "ProgWeightHist": L.hist_pw,
        "ProgWeightNew": L.new_pw,
        "PrvDisadvPropnHist": L.hist_disadv,
        "PrvHistLrgProgPropn": L.large_prog_prop,
        "PrvRetentFactHist": L.hist_retention,
        "PrvHistEnglishMathsProportion": L.hist_em_prop,
        "LearnerEnglishMathsInstances": L.em_instances,
        "RateBand": L.rate_band,
        "RetentNew": L.retent_new,
        "StartFund": L.is_start,
        "ThresholdDays": L.qualifying_period,
        "TLevelStudent": L.is_tlevel,
        "TransitionStudent": L.is_transition_student,
        "TLevelAdditionalHours": L.tl_additional_hours,
        "Year3ofTlevelStudyProgramme": L.tl_year3,
        "TLevelTQLearnAimRef": L.tq_learn_aim_ref,
        "TLevelOSLearnAimRef": L.os_learn_aim_ref,
        "TLevelProgAimActEndDate": L.tl_prog_act_end,
        "TLevelProgAimPlanEndDate": L.tl_prog_plan_end,
        "TLevelProgAimStartDate": L.tl_prog_start,
    }
    result = {k: _out(v) for k, v in out.items()}
    inter = {
        "source_of_funding": L.source_of_funding,
        "age_at_31_august": L.age,
        "total_planned_hours": L.total_planned_hours,
        "learner_start_date_this_year": L.start_this_year,
        "learner_planned_end_date_this_year": L.plan_end_this_year,
        "learner_actual_end_date_this_year": L.act_end_this_year,
        "is_summer_school_student": L.is_summer_school,
        "number_of_core_aims": L.n_core,
        "latest_core_aim_start_date": L.latest_core_start,
        "latest_tq_core_aim_start_date": L.latest_tq_core_start,
        "latest_core_aim_is_tlevel": L.latest_core_is_tlevel,
        "number_of_tlevel_programme_aims": L.n_tl_prog,
        "latest_tlevel_programme_aim_start_date": L.latest_tl_prog_start,
        "tlevel_2021_22_or_earlier_starter": L.tl_starter_2122,
        "repeating_final_year": L.repeating_final_year,
        "number_of_os_aims": L.n_os,
        "has_continuing_os_aim": L.has_continuing_os,
        "latest_os_aim_seq": L.latest_os_seq,
        "tlevel_funding_band_stage1": L.tl_funding_band_stage1,
        "tlevel_funding_band": L.tl_funding_band,
        "tlevel_pcw_stage1": L.tl_pcw_stage1,
        "tlevel_pcw": L.tl_pcw,
        "national_transition_pcw": L.national_transition_pcw,
        "number_of_transition_programme_aims": L.n_transition,
        "latest_transition_programme_aim_seq": L.latest_transition_seq,
        "low_pcw_criteria": L.low_pcw_criteria,
        "count_a_level_uplift_aims": L.count_a_level_uplift,
        "new_programme_weighting_stage1": L.new_pw_stage1,
        "base_programme_funding": L.base_programme_funding,
        "is_hns": L.is_hns, "is_ehc": L.is_ehc,
        "has_grade_c_english": L.has_eng_c, "has_grade_c_maths": L.has_maths_c,
        "has_english_grade_d": L.has_eng_d, "has_maths_grade_d": L.has_maths_d,
        "has_english_below_d": L.has_eng_below_d, "has_maths_below_d": L.has_maths_below_d,
        "english_exemption": L.eng_exemption, "maths_exemption": L.maths_exemption,
        "english_fsl2": L.eng_fsl2, "maths_fsl2": L.maths_fsl2,
        "cof_min_hours_english": L.cof_min_hours_eng, "cof_min_hours_maths": L.cof_min_hours_maths,
        "cof_not_required": L.cof_not_required,
        "has_english_instance": L.has_eng_instance, "has_maths_instance": L.has_maths_instance,
        "no_grade_c_english_by_y11": L.no_eng_c_by_y11, "no_grade_c_maths_by_y11": L.no_maths_c_by_y11,
        "latest_learning_delivery_start_date": L.latest_ld_start,
        "deliveries": [
            {
                "AimSeqNumber": d.seq,
                "is_esfa_16_19": d.m_esfa,
                "is_core_aim": d.is_core_aim,
                "is_academic_aim": d.is_academic,
                "is_general_studies_or_critical_thinking": d.is_gs_or_ct,
                "is_psychology": d.is_psychology,
                "is_kings_trust_team": d.is_kings_trust_team,
                "is_direct_funded": d.is_direct_funded,
                "is_tlevel_programme_aim": d.is_tl_prog_aim,
                "is_tlevel_transition_programme_aim": d.is_tl_transition_prog_aim,
                "is_tlevel_os_aim": d.is_tl_os_aim,
                "is_a_level_aim_attracting_uplift": d.is_a_level_uplift,
                "planned_end_date_this_year": d.plan_end_this_year,
                "planned_days": d.planned_days,
                "actual_days": d.actual_days,
                "qualifying_period": d.qualifying_period,
                "is_valid_start_for_cof": d.is_valid_start_cof,
                "planned_duration_months": d.planned_duration,
                "is_recognised_gcse_english": d.is_recognised_english,
                "is_recognised_gcse_maths": d.is_recognised_maths,
                "programme_weighting": d.programme_weighting,
                "postcode_sr_count": d.pc_sr_count,
                "applicable_postcode_sr_flag": d.pc_sr_flags_value_at_first_day,
                "tlevel_hours_amount": d.tl_hours_amount,
                "applicable_tlevel_funding_band": d.applicable_tl_funding_band,
                "applicable_tlevel_pcw": d.applicable_tl_pcw,
            }
            for d in L.lds
        ],
    }

    def conv(x):
        if isinstance(x, dict):
            return {k: conv(v) for k, v in x.items()}
        if isinstance(x, list):
            return [conv(v) for v in x]
        return _state(x)

    result["_intermediate"] = conv(inter)
    return result
