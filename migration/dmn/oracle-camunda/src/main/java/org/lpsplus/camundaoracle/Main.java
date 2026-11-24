package org.lpsplus.camundaoracle;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.camunda.bpm.dmn.engine.*;
import org.camunda.bpm.dmn.engine.delegate.*;
import org.camunda.bpm.dmn.engine.impl.DefaultDmnEngineConfiguration;
import org.camunda.bpm.engine.variable.VariableMap;
import org.camunda.bpm.engine.variable.Variables;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.math.BigDecimal;
import java.util.*;

/**
 * The second DMN oracle: Camunda 7's own DMN engine (camunda-engine-dmn, with
 * the Scala FEEL engine), for the models of Camunda Modeler, whose dialect
 * (unqualified type names, process variables as inputs) Drools does not run.
 *
 *   java -jar camunda-dmn-oracle.jar --model file.dmn --cases cases.json [--out results.json]
 *
 * cases.json: [{"id": "c1", "decision": "dish" (optional: every decision),
 *               "variables": {"season": "Spring", "guestCount": 6}}]
 * results:    [{"id": "c1", "decisions": {"dish": {"name": "Dish",
 *                "resultList": [{"desiredDish": "Steak"}],
 *                "matchedRules": [{"ruleId": "row-1", "ruleIndex": 4}]}},
 *               "error": null}]
 * The decisions a decision requires are evaluated with it, and reported too.
 */
public class Main {

    static final ObjectMapper M = new ObjectMapper().enable(SerializationFeature.INDENT_OUTPUT);

    public static void main(String[] args) throws Exception {
        String model = null, cases = null, out = null;
        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--model" -> model = args[++i];
                case "--cases" -> cases = args[++i];
                case "--out" -> out = args[++i];
                default -> { System.err.println("unknown option " + args[i]); System.exit(2); }
            }
        }
        if (model == null || cases == null) {
            System.err.println("usage: --model file.dmn --cases cases.json [--out results.json]");
            System.exit(2);
        }
        Map<String, List<ObjectNode>> matched = new LinkedHashMap<>();
        DefaultDmnEngineConfiguration conf = (DefaultDmnEngineConfiguration) DmnEngineConfiguration.createDefaultDmnEngineConfiguration();
        conf.customPostDecisionEvaluationListeners(List.of(event -> {
            record(event.getDecisionResult(), matched);
            for (DmnDecisionLogicEvaluationEvent e : event.getRequiredDecisionResults()) record(e, matched);
        }));
        DmnEngine engine = conf.buildEngine();
        List<DmnDecision> decisions;
        try (InputStream in = new FileInputStream(model)) {
            decisions = engine.parseDecisions(in);
        }
        Map<String, DmnDecision> byKey = new LinkedHashMap<>();
        for (DmnDecision d : decisions) byKey.put(d.getKey(), d);

        JsonNode cs = M.readTree(new File(cases));
        if (!cs.isArray()) cs = M.createArrayNode().add(cs);
        ArrayNode results = M.createArrayNode();
        for (JsonNode c : cs) {
            ObjectNode r = M.createObjectNode();
            r.put("id", c.path("id").asText());
            ObjectNode ds = r.putObject("decisions");
            VariableMap vars = Variables.createVariables();
            c.path("variables").fields().forEachRemaining(e -> vars.putValue(e.getKey(), toJava(e.getValue())));
            List<String> keys = c.has("decision") ? List.of(c.get("decision").asText()) : new ArrayList<>(byKey.keySet());
            try {
                for (String k : keys) {
                    DmnDecision d = byKey.get(k);
                    if (d == null) throw new IllegalArgumentException("no decision with key " + k);
                    matched.clear();
                    DmnDecisionResult res = engine.evaluateDecision(d, vars);
                    ObjectNode dn = ds.putObject(k);
                    dn.put("name", d.getName());
                    ArrayNode rl = dn.putArray("resultList");
                    for (DmnDecisionResultEntries e : res) rl.add(M.valueToTree(plain(e.getEntryMap())));
                    dn.set("matchedRules", M.valueToTree(matched.getOrDefault(k, List.of())));
                }
                r.putNull("error");
            } catch (Exception e) {
                r.put("error", String.valueOf(e.getMessage()));
            }
            results.add(r);
        }
        if (out == null) System.out.println(M.writeValueAsString(results));
        else M.writeValue(new File(out), results);
    }

    static void record(DmnDecisionLogicEvaluationEvent e, Map<String, List<ObjectNode>> matched) {
        if (e instanceof DmnDecisionTableEvaluationEvent t) {
            List<ObjectNode> rules = new ArrayList<>();
            List<?> all = ((org.camunda.bpm.dmn.engine.impl.DmnDecisionTableImpl) t.getDecision().getDecisionLogic()).getRules();
            for (DmnEvaluatedDecisionRule rule : t.getMatchingRules()) {
                ObjectNode n = M.createObjectNode();
                n.put("ruleId", rule.getId());
                int idx = 0;
                for (int i = 0; i < all.size(); i++)
                    if (((org.camunda.bpm.dmn.engine.impl.DmnDecisionTableRuleImpl) all.get(i)).getId().equals(rule.getId())) idx = i + 1;
                n.put("ruleIndex", idx);
                rules.add(n);
            }
            matched.put(t.getDecision().getKey(), rules);
        }
    }

    static Object toJava(JsonNode v) {
        if (v.isNull()) return null;
        if (v.isBoolean()) return v.booleanValue();
        if (v.isIntegralNumber()) return v.canConvertToInt() ? (Object) v.intValue() : (Object) v.longValue();
        if (v.isNumber()) return v.doubleValue();
        if (v.isTextual()) return v.textValue();
        return M.convertValue(v, Object.class);
    }

    static Map<String, Object> plain(Map<String, Object> m) {
        Map<String, Object> r = new LinkedHashMap<>();
        for (Map.Entry<String, Object> e : m.entrySet()) {
            Object v = e.getValue();
            if (v instanceof BigDecimal b) v = b.stripTrailingZeros();
            r.put(e.getKey(), v);
        }
        return r;
    }
}
