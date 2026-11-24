# DMN oracle

A headless harness on the Apache KIE Drools DMN engine. It evaluates DMN models on given inputs and prints the
decision requirements graph (DRG) that Drools sees. The DMN to Logical English translator uses it as an oracle: it
compares the answers of its translations against the answers of Drools.

- Engine: Apache KIE Drools DMN **10.2.0** (`org.kie:kie-dmn-core`, `kie-dmn-api`, from Maven Central). This is
  the newest 10.x release on Maven Central, and the version that the DMN TCK publishes results for
  (`TestResults/Drools/10.2.0`).
- Java 21, Maven 3.9. JSON with Jackson 2.17. Logging with slf4j-simple (off unless you pass `--log`).
- The engine is set up the same way as in the official TCK runner (`runners/dmn-tck-runner-drools`,
  `DMNRuntimeBuilder.usingStrict()`): runtime type check on, no Drools extended profile, lenient runtime mode.

## Build and run

```sh
./build.sh                    # mvn -q package, local repository in ./.m2 (gitignored)
java -Xmx2g -jar target/dmn-oracle.jar <command> ...
```

```
java -jar dmn-oracle.jar eval --models <file-or-dir>... --cases cases.json [--out results.json]
java -jar dmn-oracle.jar drg  --models <file-or-dir>... [--out drg.json] [--summary]
java -jar dmn-oracle.jar tck  <TestCases dir> [--out tck-results.json]
java -jar dmn-oracle.jar version
options: --normalise  --no-typecheck  --extended-profile  --log <off|error|warn|info|debug>
```

Without `--out`, JSON goes to standard output. Progress lines go to standard error.

- `--models` takes files and directories. A directory is searched recursively for `*.dmn` files, and for `*.xml`
  files whose root element is a DMN `definitions`. All the files are loaded together. Imports are resolved by
  namespace (and by `drools:modelName` when the namespace is not unique) among all the files, in dependency order,
  so a directory with models that import each other just works. A broken file does not stop the others. When two
  files have the same namespace and name, the second one is compiled separately in a second runtime (the `drg`
  output gives a note).
- `--no-typecheck` turns off the runtime type check. Kogito and the Drools default have it off. The TCK runner has it
  on. See the STTR and BDT results below for the cases where this matters.
- `--extended-profile` adds the Drools extended FEEL functions (not standard DMN).
- `--normalise` applies in-memory rewrites for the Camunda Modeler dialect (see below). Files on disk are never
  changed.

## JSON formats

`cases.json` is one case or a list of cases:

```json
[{"id": "c1",
  "model": {"namespace": "...", "name": "..."},
  "decisions": ["Decision A", "Decision B"],
  "inputs": {"Input name": 42, "Applicant": {"age": 30, "birth": {"@type": "date", "value": "1995-01-01"}}}}]
```

- `model`: `{"namespace", "name"}` (either can be left out if the rest is unique), `{"file": "path"}`, or a string
  path. A path matches the full path or the end of a path. With one model loaded, `model` can be left out.
- `decisions`: optional. Without it, all decisions of the model (not the imported ones) are evaluated.
- `decisionService`: optional, the name of a decision service to invoke instead. The results are its output
  decisions.
- `inputs`: input data names to values. A decision name can also be given, as a pre-evaluated decision (as in the
  TCK). The inputs of an imported model go in a context named after the import:
  `{"ImportName": {"input": ...}}`.

`results.json` has one entry for each case:

```json
{"id": "c1", "results": {"Decision A": 1.5, "Decision B": null},
 "messages": ["ERROR ERROR_EVAL_NODE DMN: ..."],
 "decisionStatus": {"Decision A": "SUCCEEDED", "Decision B": "FAILED"},
 "hasErrors": true, "status": "ok", "millis": 1.4}
```

`status` is `"error"` only when the harness could not evaluate (the model was not found or did not compile, or a bad
input). Then `messages` starts with `HARNESS`. DMN evaluation errors give `status: "ok"`, `hasErrors: true`, a
`FAILED` or `SKIPPED` decision status and a `null` result, which is the DMN semantics. Messages are
`SEVERITY TYPE text`. The compile errors of the model come first, with the prefix `COMPILE`.

Value mapping, both ways:

| FEEL | JSON |
|---|---|
| number (BigDecimal) | a JSON number, written exactly with `toPlainString`, trailing zeros stripped (`5`, `0.1`, `2778.693549432766768088520383236299`). Inputs are read as BigDecimal, with no loss through double. A string is read as a number when the input type is `number`. |
| string, boolean, null | the same |
| list | an array |
| context | an object (key order as Drools gives it) |
| date | `{"@type":"date","value":"2020-01-01"}` |
| date and time | `{"@type":"dateTime","value":"2016-12-24T23:59:00-08:00"}` (zone ids as `...@Europe/Paris`) |
| time | `{"@type":"time","value":"00:00:01-01:00"}` |
| duration | `{"@type":"duration","value":"P1Y2M"}` or `"P1DT2H"` (FEEL format, days not folded into hours) |
| range | `{"@type":"range","startIncluded":true,"start":1,"end":10,"endIncluded":false,"feel":"[ 1 .. 10 )"}`. `null` start or end means an open-ended range. Best effort. |
| function | `{"@type":"function","name":"..."}` (output only) |
| anything else | `{"@type":"unknown","class":"...","value":"toString"}` |

A plain string input is also converted to a date, time, date and time or duration when the declared input type is
one of these.

`drg` prints a list with one object for each file: `file`, `compiled` (no ERROR message), `name`, `namespace`, `id`,
`exporter`, `imports` (with `resolvedFile`), `itemDefinitions`, `inputData` (`name`, `typeRef` as written, `type` as
Drools resolved it), `decisions` (`name`, `typeRef`, `type`, `requiredDecisions`, `requiredInputs`,
`requiredKnowledge`, `logic`), `bkms`, `decisionServices` (output, encapsulated, input decisions, input data),
`knowledgeSources`, `messages` (`severity`, `type`, `text`, `sourceId`; LOADER messages are the harness's own), and
`normalisations` when `--normalise` changed something. References to imported elements are named
`ImportName.Element`. `logic` gives the kind of the expression: `decisionTable` (`hitPolicy`, `aggregation`,
`inputs`, `outputs`, `rules`), `literalExpression` (`text`), `context` (`entries`), `invocation`, `list`, `relation`,
`functionDefinition` (`functionKind`, `parameters`, `body`), `conditional`, `filter`, `for`/`every`/`some`, `none`.

`tck` runs every `*-test-NN.xml` under `compliance-level-2` and `compliance-level-3`, like the official runner. It
loads the main model and every `.dmn` in the folder, reads the values the same way (a port of `parseType` on DOM
instead of JAXB), evaluates the result nodes one after the other in one context, and compares with
`CompareValuesUtil` (numbers equal to within 1e-8). It prints one line for each test file and the totals. The
summary goes to standard output; the `--out` JSON has every case with `status` (`pass`, `fail`, `error`), `failures` and the `actual` values.

## Normalisation (`--normalise`)

The STTR files need no normalisation. Drools loads the DMN 1.1 namespace, the literal `${oin}` in the namespace and
the RuleArts extension elements as they are.

The rewrites are for Camunda Modeler files (RONL). Each rewrite that fires is listed in the `drg` output:

1. `missing-variable`: a decision, input data or BKM without `<variable>` gets one with the element's name. Its
   typeRef is the single decision-table output typeRef or the literal-expression typeRef, if there is one.
2. `java-typeRef`: `typeRef` `integer`, `long`, `int`, `short`, `double`, `float`, `decimal` becomes `number`, unless an
   itemDefinition has that name.
3. `empty-input-entry`: an empty decision-table input entry becomes `-`.
4. `missing-requirement`: only in files exported by Camunda or declaring the camunda namespace. A decision whose
   texts mention, as a whole word, an input data or another decision of the model without an information
   requirement gets the requirement. (Applied to every file, rewrite 4 changed two TCK results. Restricted to Camunda
   files, the TCK totals with and without `--normalise` are the same.)

Nothing else is changed. Camunda features that cannot be rewritten safely stay errors: a reference to the output
column name of another decision instead of the decision name, a variable that comes only from the process, and
names with `:` or `(`.

## Results (2026-10-26)

**TCK** (commit 1e349176, 3,407 cases, 14 to 30 s): **3,396 passed, 8 failed, 3 errors**.
On the 3,391 cases of the published Drools 10.2.0 results: 3,389 pass (published: 3,388). The two failures are the
published ones (`0068-feel-equality` `range_010`, `range_012`). `0085-decision-services` `015` passes here and
fails in the published run. The other 9 failures are in the 16 newer cases: `1157-implicit-conversions` (3 test
cases of type `bkm`, which the runner cannot type; 2 singleton-list conversions; 2 date-time values printed as
`00:00Z` and expected as `00:00:00Z`) and `1160-multiple-imports` (2, the runner ignores the `namespace` of an
input node).

**STTR** (196 files, `gemeenten` + `waterschappen`): **196 of 196 compile** with no message at all, without
normalisation (16 s to load all of them). Evaluation (2 cases for each model, all boolean inputs true and then
false): no harness errors. A median of 1.4 ms for each case. With the type check on, 29 of the 392 cases give an
error: the `Conclusie` decisions have hit policy COLLECT and are declared `feel:string`, so an empty collection
(`[]`) fails the type check and becomes `null`. With `--no-typecheck` the result is `[]`, and a one-element list is
taken as its element in both modes.

**BDT** (`.cache/bdt`, 39 files, 37 distinct models): **38 of 39 compile**, with imports resolved from sibling
directories (`library-api/src/main/resources` as one directory, 34 files, 3.5 s). The one that does not is
`BDT.dmn`: its BKM `invoke decision service` is a Java function (`org.codeforphilly.bdt.library.functions.
DecisionServiceInvoker`) from the BDT Java code. The models that import `BDT.dmn` compile. The two seed-data
`W-*.dmn` files are duplicates (same namespace and name), so they are compiled separately. The Bruno tests
(`library-api/test/**/*.bru`: 176 requests to the decision service of a check, with 175 `checkResult` asserts) all
match with `--no-typecheck` (175/175, a median of 5 ms for each case). With the type check on, 120 do not match,
because the decision services are declared `tCheckResponse` and return a boolean (Kogito runs with the type check
off).

**RONL** (`.cache/ronl`, 36 files, 17 distinct models, most of them copied 2 or 3 times): **4 of 36 compile**
unchanged (the 4 STTR-builder `.xml` files). **19 of 36 compile with `--normalise`** (8 of the 17 distinct models).
Errors before normalisation, by kind: MISSING_VARIABLE (decisions and input data without `<variable>`),
TYPE_DEF_NOT_FOUND / MISSING_TYPE_REF (`integer`, `double`), MISSING_EXPRESSION (empty input entries),
ERR_COMPILING_FEEL "Unknown variable" (no information requirements) and REQ_NOT_FOUND. Errors that remain after
normalisation: "Unknown variable" (references to output names and process variables, in 12 files), and INVALID_NAME
(names with `:` or `(`, in 5 files).

## Caveats

- Numbers: exact decimals are kept, so a result like `10/3` comes out with 34 digits
  (`3.333333333333333333333333333333333`). A JSON reader that reads numbers as floating point loses the extra
  digits. Compare to within a tolerance (the TCK uses 1e-8) or read the number text.
- `null` is a value: a decision that fails gives `null` with `decisionStatus` `FAILED`. A decision that is not
  evaluated (a missing input) gives `SKIPPED`. Look at `decisionStatus` and `messages`, not only at the value.
- Key order in contexts is the order Drools gives, which is not always the order in the model.
- The first evaluation in a process is slower (100 to 200 ms, JIT warm-up). After that, a decision-table model takes
  1 to 5 ms for each case. Loading takes about 80 ms for each STTR model.
- Saxon (used by Drools for the FEEL `matches()` and `replace()` functions) prints regular-expression errors of the TCK error cases straight to standard error; they are not harness errors.
- Memory: `-Xmx2g` is enough for all the corpora above (the TCK run is the largest).
