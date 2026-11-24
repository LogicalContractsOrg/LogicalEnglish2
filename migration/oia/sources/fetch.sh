#!/usr/bin/env bash
# Fetch the public Oracle Intelligent Advisor (Oracle Policy Automation)
# projects the OIA reader is developed and tested on, into sources/.cache/.
# None of the repositories states a licence: the full projects stay in this
# local cache; each twin (kept in the private InsurLE repository, not
# redistributed) has a copy of its project's text files beside it, in
# sources/project/, for the editors' Show the Original. Re-run to refresh.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .cache
cd .cache
clone() { # repo dir
  if [ -d "$2/.git" ]; then git -C "$2" pull -q --ff-only || true
  else git clone -q --depth 1 "https://github.com/$1" "$2"; fi
}
clone NixonS24/Oracle-Policy-Modeling nixon
clone yihsiang/opa_demo opa_demo
clone Intelligent-Advisor/oia-dmn-tree oia-dmn-tree
clone ministryofjustice/opa_tools opa_tools
# the second corpus (October 2026): Oracle's own samples, the Ministry of
# Justice's rulebases, and the Loan Advisor demonstration rulebase
clone oracle-samples/ia-tools-samples oracle-samples_ia-tools-samples
clone ministryofjustice/laa-ccms-opa-feedback-form-v23-ruletxt ministryofjustice_laa-ccms-opa-feedback-form-v23-ruletxt
clone ministryofjustice/govuk-elements-for-oracle-policy-automation ministryofjustice_govuk-elements-for-oracle-policy-automation
if [ ! -d NealOKelly_govuk-opa-maf-template/.git ]; then   # 230 MB: only the one file is checked out
  git clone -q --filter=blob:none --no-checkout https://github.com/NealOKelly/govuk-opa-maf-template NealOKelly_govuk-opa-maf-template
fi
git -C NealOKelly_govuk-opa-maf-template checkout -q HEAD -- ".adf/META-INF/Loan Advisor.zip"
mkdir -p oracle_ds loan_advisor moj_check_answers
cp oracle-samples_ia-tools-samples/llm/llm_ds_chat/decision-services/*.json oracle_ds/
cp "oracle-samples_ia-tools-samples/samples/flows/student-benefits/Student Benefits.json" oracle_ds/student_benefits.json
python3 - <<'PY'
import zipfile
zipfile.ZipFile("NealOKelly_govuk-opa-maf-template/.adf/META-INF/Loan Advisor.zip").extractall("loan_advisor")
zipfile.ZipFile("ministryofjustice_govuk-elements-for-oracle-policy-automation/CheckAnswers.zip").extractall("moj_check_answers")
PY
echo "fetched into $(pwd)"
