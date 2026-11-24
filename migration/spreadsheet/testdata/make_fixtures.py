"""The fixture workbooks of test_spreadsheet.pl (written with openpyxl; no
values are saved for the formulas, so only the sheet engine computes them)."""
import openpyxl
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.styles import Protection

wb = openpyxl.Workbook()
calc = wb.active; calc.title = "Calc"
br = wb.create_sheet("Brackets")
br["A1"], br["B1"] = "Income from", "Rate"
for i, (k, r) in enumerate([(0, 0), (12000, 0.2), (50000, 0.4)], start=2):
    br.cell(i, 1, k); br.cell(i, 2, r)
calc["A1"], calc["B1"] = "Income", 42000
calc["A2"], calc["B2"] = "Rate", "=VLOOKUP(B1,Brackets!A2:B4,2,TRUE)"
calc["A3"], calc["B3"] = "Tax", "=IF(B1<12000,0,ROUND(B1*B2,2))"
calc["A4"], calc["B4"] = "Is the taxpayer resident?", "y"
calc["A5"], calc["B5"] = "Tax due", '=IF(B4="y",B3,"not resident")'
calc["A6"], calc["B6"] = "Surcharge", '=IF(OR(B1>100000,B4="n"),"$250.00",0)+0'
dv = DataValidation(type="list", formula1='"y,n"'); calc.add_data_validation(dv); dv.add("B4")
calc["B1"].protection = Protection(locked=False)
calc.protection.sheet = True
wb.save("tax.xlsx")

# A body-mass-index calculator from the CDC's published adult formula (BMI =
# weight in kilograms / height in metres squared, rounded to one decimal) and
# the ICD-10-CM codes Z68.1-Z68.45 for adult BMI ranges. Made here, because
# the CDC's own workbooks could not be downloaded from this machine.
wb = openpyxl.Workbook()
ws = wb.active; ws.title = "BMI"
codes = wb.create_sheet("Z68 codes")
codes["A1"], codes["B1"] = "BMI from", "ICD-10-CM code"
bands = [(0, "Z68.1")] + [(20 + i, f"Z68.2{i}") for i in range(10)] + [(30 + i, f"Z68.3{i}") for i in range(10)] \
        + [(40, "Z68.41"), (45, "Z68.42"), (50, "Z68.43"), (60, "Z68.44"), (70, "Z68.45")]
for i, (k, c) in enumerate(bands, start=2):
    codes.cell(i, 1, k); codes.cell(i, 2, c)
ws["A1"], ws["B1"] = "Weight (kg)", 70
ws["A2"], ws["B2"] = "Height (cm)", 175
ws["A3"], ws["B3"] = "Body mass index", "=ROUND(B1/(B2/100)^2,1)"
ws["A4"], ws["B4"] = "ICD-10-CM code for the BMI", f"=VLOOKUP(B3,'Z68 codes'!A2:B{len(bands)+1},2,TRUE)"
ws["A5"], ws["B5"] = "Category", '=IF(B3<18.5,"Underweight",IF(B3<25,"Healthy weight",IF(B3<30,"Overweight","Obesity")))'
for c in ("B1", "B2"):
    ws[c].protection = Protection(locked=False)
ws.protection.sheet = True
wb.save("adult_bmi.xlsx")

# The review's idioms (a review that is not published (Spreadsheet_auditorReport)): a regional
# grant with INDEX/MATCH, VLOOKUP, CHOOSE, MAX, ROUND, EDATE on a date input, a
# percentage input, a name used in a formula, COUNTIF with ">"&cell, SUMIF.
import datetime
from openpyxl.workbook.defined_name import DefinedName
wb = openpyxl.Workbook(); ws = wb.active; ws.title = "Grant"
rates = wb.create_sheet("Rates")
rates.append(["Region", "Base grant", "Uplift"])
for r in [("North", 1200, 0.10), ("South", 1000, 0.05), ("East", 1100, 0.08), ("West", 950, 0.0)]: rates.append(list(r))
rows = [("Applicant's region", "North"), ("Annual income", 18000), ("Number of dependants", 2),
        ("Date of application", datetime.date(2026, 3, 15)), ("Disability uplift %", 0.15)]
for i, (l, v) in enumerate(rows, start=1):
    ws.cell(i, 1, l); c = ws.cell(i, 2, v); c.protection = Protection(locked=False)
ws["B4"].number_format = "dd/mm/yyyy"; ws["B5"].number_format = "0%"
ws["A7"], ws["B7"] = "Base grant", "=INDEX(Rates!B2:B5,MATCH(B1,Rates!A2:A5,0))"
ws["A8"], ws["B8"] = "Regional uplift", "=VLOOKUP(B1,Rates!A2:C5,3,FALSE)"
ws["A9"], ws["B9"] = "Dependant allowance", "=CHOOSE(MIN(B3,3)+1,0,250,450,600)"
ws["A10"], ws["B10"] = "Income test", '=IF(B2<=20000,"Eligible","Not eligible")'
ws["A11"], ws["B11"] = "Grant before tapering", "=B7*(1+B8+B5)+B9"
ws["A12"], ws["B12"] = "Taper", "=MAX(0,(B2-15000)*0.2)"
ws["A13"], ws["B13"] = "Grant payable", '=IF(B10="Eligible",ROUND(MAX(0,B11-B12),0),0)'
ws["A14"], ws["B14"] = "Decision due by", "=EDATE(B4,2)"; ws["B14"].number_format = "dd/mm/yyyy"
ws["A15"], ws["B15"] = "Grant payable per month", "=ROUNDDOWN(Grant_payable/12,2)"
ws["A16"], ws["B16"] = "Regions with a higher base grant", '=COUNTIF(Rates!B2:B5,">"&B7)'
ws["A17"], ws["B17"] = "Total base grants", '=SUMIF(Rates!C2:C5,">0",Rates!B2:B5)'
wb.defined_names["Grant_payable"] = DefinedName("Grant_payable", attr_text="Grant!$B$13")
ws.protection.sheet = True
wb.save("grant.xlsx")
