#!/bin/sh
# The public spreadsheets of the design notes Excel.md §1 and §7.7, into
# .cache/files (gitignored). Each line: the name we keep it under, its URL.
# Government sites move files often: a failed download is reported, never
# fatal, and the survey (Excel.md §2) gives the publisher's page to search.
cd "$(dirname "$0")"
mkdir -p .cache/files
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140 Safari/537.36"
fetch() {
    if [ -s ".cache/files/$1" ]; then return 0; fi
    if curl -sSfL -A "$UA" --max-time 400 -o ".cache/files/$1" "$2"; then
        echo "fetched $1"
    else
        rm -f ".cache/files/$1"; echo "FAILED $1  ($2)"
    fi
}
while read -r name url; do
    case "$name" in ''|'#'*) continue ;; esac
    fetch "$name" "$url"
done <<'LIST'
ma_snap_2026_10.xlsx https://www.masslegalservices.org/system/files/library/MLRI%20Massachuestts%20SNAP%20Calculator%2C%20October%202026.xlsx
cbam_template.xlsx https://taxation-customs.ec.europa.eu/document/download/2c15cd0e-2447-4ef8-ab70-68b80b66ede8_en?filename=CBAM%20Communication%20template%20for%20installations_en_20241213.xlsx
cbam_examples.zip https://taxation-customs.ec.europa.eu/document/download/8d00a979-e57d-4e53-a11f-8b01370236a9_en?filename=Communication-template-examples.zip
br_prlf.xlsx https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/formularios/impostos/transacao/simulador-prlf.xlsx/@@download/file
cms_sbc_calculator.xlsm https://www.cms.gov/files/document/234400-sbc-coverage-examples-calculator-excel-050522.xlsm
cms_mlr_2025.xlsm https://www.cms.gov/files/document/2025-mlr-calculator.xlsm
eba_lcr_tool.xlsx https://www.eba.europa.eu/documents/10180/1124078/LCR+Calculation+Tool.xlsx/e0b3b57e-00ee-4cb2-9f91-bf7d44a47555
bis_basel3_monitoring.xlsx https://www.bis.org/pages/basel-iii-monitoring-and-qis/biiiimplmoniwb-560.xlsx
or_child_support.xls https://justice.oregon.gov/child-support/xls/child_support_worksheet.xls
ok_child_support.xlsm https://oklahoma.gov/content/dam/ok/en/okdhs/documents/okdhs-document-library/excel/CSGuidelinesAccessible050125.xlsm
sc_mva_ajustada.xlsx https://www.sef.sc.gov.br/api/download?id=5449&nomeArquivo=Planilha_Calculo_MVA_Ajustada.xlsx&mime=application%2Fvnd.openxmlformats-officedocument.spreadsheetml.sheet
nl_nibud_2026.xlsx https://www.nibud.nl/download/22375/
ky_withholding_2026.xlsx https://revenue.ky.gov/Business/Documents/2026%20Withholding%20Tax%20Calculator.xlsx
pt_irs_simplificado.xlsx https://www.occ.pt/fotos/editor2/simulador_simplificado_irs.xlsx
pr_simples_nacional.xlsx https://www.fazenda.pr.gov.br/sites/default/arquivos_restritos/files/documento/2025-11/CALCULADORA%20SIMPLES%20NACIONAL%20ICMS-PR.xlsx
wa_levy_64-0007.xlsx https://dor.wa.gov/sites/default/files/2022-02/64-0007.xlsx
cdc_bmi_group_metric.xls https://www.cdc.gov/healthyweight/xls/bmi_group_calculator_metric.xls
eba_nsfr_tool.xlsx https://www.eba.europa.eu/sites/default/files/document_library/Publications/Draft%20Technical%20Standards/2020/ITS/ITS%20on%20supervisory%20reporting%20changes%20related%20to%20CRR2%20and%20Backstop%20Regulation/Annexes/886578/NSFR%20calculation%20tool.xlsx
fed_scale_tool.xlsx https://www.supervisionoutreach.org/-/media/files/supervisionoutreach/cecl/scale_tool_blank.xlsx?sc_lang=en&hash=BDA3DD10589E07C248910A0E0E92F79E
ncua_capital.zip https://ncua.gov/files/publications/regulation-supervision/complex-credit-union-risk-based-capital-calculator.zip
it_definizione_agevolata.xlsx https://www.agenziaentrate.gov.it/portale/documents/20143/4968952/Definizione+agevolata+rateazioni+in+corso+commi+155-156+LB+2023+v1.3.xlsx/d0360cf7-57df-3b57-c44e-a6c52fda6bec
pt_ta_2026.xlsm https://www.occ.pt/sites/default/files/public/2026-09/Simulador%20TA-Continente%20e%20RA%20Madeira2026.xlsm
LIST
