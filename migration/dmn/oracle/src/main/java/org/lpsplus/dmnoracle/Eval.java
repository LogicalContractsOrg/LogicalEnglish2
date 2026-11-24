package org.lpsplus.dmnoracle;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.kie.dmn.api.core.DMNContext;
import org.kie.dmn.api.core.DMNDecisionResult;
import org.kie.dmn.api.core.DMNMessage;
import org.kie.dmn.api.core.DMNModel;
import org.kie.dmn.api.core.DMNResult;
import org.kie.dmn.api.core.DMNType;
import org.kie.dmn.api.core.ast.DecisionNode;
import org.kie.dmn.api.core.ast.DecisionServiceNode;
import org.kie.dmn.api.core.ast.InputDataNode;
import org.kie.dmn.model.api.DMNElementReference;

import static org.lpsplus.dmnoracle.Json.F;

/** Evaluates the cases of a cases.json against a ModelSet. */
public final class Eval {

    private final ModelSet ms;

    public Eval(ModelSet ms) {
        this.ms = ms;
    }

    public ArrayNode run(JsonNode cases) {
        ArrayNode out = F.arrayNode();
        if (cases.isObject()) {   // a single case
            out.add(one(cases));
            return out;
        }
        for (JsonNode c : cases) {
            out.add(one(c));
        }
        return out;
    }

    ObjectNode one(JsonNode c) {
        ObjectNode r = F.objectNode();
        r.set("id", c.get("id") == null ? F.nullNode() : c.get("id"));
        ObjectNode results = F.objectNode();
        ArrayNode messages = F.arrayNode();
        r.set("results", results);
        r.set("messages", messages);
        long t0 = System.nanoTime();
        try {
            JsonNode m = c.get("model");
            ModelSet.LoadedFile lf;
            if (m == null || m.isNull()) {
                lf = ms.files.size() == 1 ? ms.files.get(0) : null;
                if (lf == null) {
                    throw new IllegalArgumentException("no \"model\" given and more than one model loaded");
                }
            } else if (m.isTextual()) {
                lf = ms.find(m.textValue(), null, null);
            } else {
                lf = ms.find(m.path("file").asText(null), m.path("namespace").asText(null), m.path("name").asText(null));
            }
            if (lf == null) {
                throw new IllegalArgumentException("model not found: " + m);
            }
            if (lf.model == null) {
                throw new IllegalStateException("model did not compile: " + String.join("; ", lf.loadErrors));
            }
            DMNModel model = lf.model;
            for (DMNMessage dm : model.getMessages(DMNMessage.Severity.ERROR)) {
                messages.add("COMPILE " + msg(dm));
            }
            DMNContext ctx = lf.runtime.newContext();
            JsonNode inputs = c.path("inputs");
            Iterator<Map.Entry<String, JsonNode>> it = inputs.fields();
            while (it.hasNext()) {
                Map.Entry<String, JsonNode> e = it.next();
                ctx.set(e.getKey(), Json.toFeel(e.getValue(), typeOf(model, e.getKey())));
            }
            DMNResult res;
            List<String> wanted = new ArrayList<>();
            String ds = c.path("decisionService").asText(null);
            if (ds != null) {
                DecisionServiceNode dsn = model.getDecisionServices().stream().filter(d -> d.getName().equals(ds)).findFirst()
                        .orElseThrow(() -> new IllegalArgumentException("no decision service named '" + ds + "'"));
                res = lf.runtime.evaluateDecisionService(model, ctx, ds);
                for (DMNElementReference ref : dsn.getDecisionService().getOutputDecision()) {
                    String id = ref.getHref().substring(ref.getHref().indexOf('#') + 1);
                    DecisionNode dn = model.getDecisionById(id);
                    if (dn != null) {
                        wanted.add(dn.getName());
                    }
                }
            } else if (c.has("decisions") && c.get("decisions").isArray()) {
                for (JsonNode d : c.get("decisions")) {
                    wanted.add(d.asText());
                }
                res = lf.runtime.evaluateByName(model, ctx, wanted.toArray(new String[0]));
            } else {
                res = lf.runtime.evaluateAll(model, ctx);
                for (DecisionNode dn : model.getDecisions()) {
                    if (dn.getModelNamespace().equals(model.getNamespace())) {
                        wanted.add(dn.getName());
                    }
                }
                wanted.sort(null);
            }
            ObjectNode statuses = F.objectNode();
            for (String w : wanted) {
                DMNDecisionResult dr = res.getDecisionResultByName(w);
                Object v;
                if (dr != null) {
                    v = dr.getResult();
                    statuses.put(w, dr.getEvaluationStatus().name());
                } else {
                    v = res.getContext().get(w);
                    statuses.put(w, res.getContext().isDefined(w) ? "IN_CONTEXT" : "NOT_FOUND");
                }
                if (ds != null && v == null && res.getContext().isDefined(w)) {
                    v = res.getContext().get(w);
                }
                results.set(w, Json.toJson(v));
            }
            for (DMNMessage dm : res.getMessages()) {
                messages.add(msg(dm));
            }
            r.set("decisionStatus", statuses);
            r.put("hasErrors", res.hasErrors());
            r.put("status", "ok");
        } catch (Throwable t) {
            messages.add("HARNESS " + ModelSet.oneLine(t));
            r.put("status", "error");
        }
        r.put("millis", (System.nanoTime() - t0) / 1_000_000.0);
        return r;
    }

    static String msg(DMNMessage dm) {
        return dm.getSeverity() + " " + (dm.getMessageType() == null ? "" : dm.getMessageType() + " ") + dm.getText();
    }

    private static DMNType typeOf(DMNModel model, String name) {
        InputDataNode in = model.getInputByName(name);
        if (in != null) {
            return in.getType();
        }
        DecisionNode dn = model.getDecisionByName(name);   // a pre-evaluated decision given as an input
        if (dn != null) {
            return dn.getResultType();
        }
        return null;
    }
}
