package org.lpsplus.dmnoracle;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.xml.namespace.QName;

import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.kie.dmn.api.core.DMNMessage;
import org.kie.dmn.api.core.DMNType;
import org.kie.dmn.api.core.ast.DecisionNode;
import org.kie.dmn.api.core.ast.InputDataNode;
import org.kie.dmn.model.api.BusinessKnowledgeModel;
import org.kie.dmn.model.api.Conditional;
import org.kie.dmn.model.api.Context;
import org.kie.dmn.model.api.ContextEntry;
import org.kie.dmn.model.api.DMNElementReference;
import org.kie.dmn.model.api.DRGElement;
import org.kie.dmn.model.api.Decision;
import org.kie.dmn.model.api.DecisionService;
import org.kie.dmn.model.api.DecisionTable;
import org.kie.dmn.model.api.Definitions;
import org.kie.dmn.model.api.Expression;
import org.kie.dmn.model.api.Filter;
import org.kie.dmn.model.api.FunctionDefinition;
import org.kie.dmn.model.api.Import;
import org.kie.dmn.model.api.InformationItem;
import org.kie.dmn.model.api.InformationRequirement;
import org.kie.dmn.model.api.InputClause;
import org.kie.dmn.model.api.InputData;
import org.kie.dmn.model.api.Invocation;
import org.kie.dmn.model.api.Iterator;
import org.kie.dmn.model.api.KnowledgeRequirement;
import org.kie.dmn.model.api.KnowledgeSource;
import org.kie.dmn.model.api.LiteralExpression;
import org.kie.dmn.model.api.OutputClause;
import org.kie.dmn.model.api.Relation;

import static org.lpsplus.dmnoracle.Json.F;

/** The decision requirements graph of a model, as JSON. Built from the parsed definitions, enriched with Drools' types. */
public final class Drg {

    private final ModelSet ms;

    public Drg(ModelSet ms) {
        this.ms = ms;
    }

    public ObjectNode describe(ModelSet.LoadedFile lf) {
        ObjectNode o = F.objectNode();
        o.put("file", lf.path.toString());
        Definitions d = lf.defs;
        if (!lf.normalisations.isEmpty()) {
            ArrayNode a = o.putArray("normalisations");
            lf.normalisations.forEach(a::add);
        }
        if (!lf.notes.isEmpty()) {
            ArrayNode a = o.putArray("notes");
            lf.notes.forEach(a::add);
        }
        boolean errors = !lf.loadErrors.isEmpty() || lf.model == null;
        ArrayNode msgs = F.arrayNode();
        for (String e : lf.loadErrors) {
            ObjectNode m = msgs.addObject();
            m.put("severity", "ERROR");
            m.put("type", "LOADER");
            m.put("text", e);
        }
        if (lf.model != null) {
            for (DMNMessage dm : lf.model.getMessages()) {
                ObjectNode m = msgs.addObject();
                m.put("severity", dm.getSeverity().name());
                m.put("type", dm.getMessageType() == null ? null : dm.getMessageType().name());
                m.put("text", dm.getText());
                if (dm.getSourceId() != null) {
                    m.put("sourceId", dm.getSourceId());
                }
                if (dm.getSeverity() == DMNMessage.Severity.ERROR) {
                    errors = true;
                }
            }
        }
        o.put("compiled", !errors);
        if (d == null) {
            o.set("messages", msgs);
            return o;
        }
        o.put("name", d.getName());
        o.put("namespace", d.getNamespace());
        o.put("id", d.getId());
        if (d.getExporter() != null) {
            o.put("exporter", d.getExporter() + (d.getExporterVersion() != null ? " " + d.getExporterVersion() : ""));
        }
        ArrayNode imps = o.putArray("imports");
        for (Import i : d.getImport()) {
            ObjectNode io = imps.addObject();
            io.put("name", i.getName());
            io.put("namespace", i.getNamespace());
            io.put("locationURI", i.getLocationURI());
            io.put("importType", i.getImportType());
            ModelSet.LoadedFile t = importedFile(i);
            if (t != null) {
                io.put("resolvedFile", t.path.toString());
                io.put("modelName", t.defs.getName());
            }
        }
        ArrayNode items = o.putArray("itemDefinitions");
        d.getItemDefinition().forEach(it -> items.add(it.getName()));

        Map<String, String> ids = idIndex(d, "");
        for (Import i : d.getImport()) {
            ModelSet.LoadedFile t = importedFile(i);
            if (t != null) {
                ids.putAll(idIndex(t.defs, i.getNamespace() + "#", i.getName().isEmpty() ? "" : i.getName() + "."));
            }
        }

        ArrayNode inputs = o.putArray("inputData");
        ArrayNode decisions = o.putArray("decisions");
        ArrayNode bkms = o.putArray("bkms");
        ArrayNode dss = o.putArray("decisionServices");
        ArrayNode kss = o.putArray("knowledgeSources");
        List<DecisionService> services = new ArrayList<>(d.getDecisionService());
        for (DRGElement e : d.getDrgElement()) {
            if (e instanceof InputData in) {
                ObjectNode io = inputs.addObject();
                io.put("name", in.getName());
                io.put("id", in.getId());
                io.put("typeRef", typeRef(in.getVariable()));
                if (lf.model != null) {
                    InputDataNode n = lf.model.getInputById(in.getId());
                    if (n != null) {
                        io.set("type", type(n.getType()));
                    }
                }
            } else if (e instanceof Decision dec) {
                ObjectNode dn = decisions.addObject();
                dn.put("name", dec.getName());
                dn.put("id", dec.getId());
                dn.put("typeRef", typeRef(dec.getVariable()));
                if (lf.model != null) {
                    DecisionNode n = lf.model.getDecisionById(dec.getId());
                    if (n != null) {
                        dn.set("type", type(n.getResultType()));
                    }
                }
                ArrayNode rd = dn.putArray("requiredDecisions");
                ArrayNode ri = dn.putArray("requiredInputs");
                for (InformationRequirement ir : dec.getInformationRequirement()) {
                    if (ir.getRequiredDecision() != null) {
                        rd.add(ref(ir.getRequiredDecision(), ids));
                    }
                    if (ir.getRequiredInput() != null) {
                        ri.add(ref(ir.getRequiredInput(), ids));
                    }
                }
                ArrayNode rk = dn.putArray("requiredKnowledge");
                for (KnowledgeRequirement kr : dec.getKnowledgeRequirement()) {
                    if (kr.getRequiredKnowledge() != null) {
                        rk.add(ref(kr.getRequiredKnowledge(), ids));
                    }
                }
                dn.set("logic", expr(dec.getExpression()));
            } else if (e instanceof BusinessKnowledgeModel bkm) {
                ObjectNode bn = bkms.addObject();
                bn.put("name", bkm.getName());
                bn.put("id", bkm.getId());
                bn.put("typeRef", typeRef(bkm.getVariable()));
                ArrayNode rk = bn.putArray("requiredKnowledge");
                for (KnowledgeRequirement kr : bkm.getKnowledgeRequirement()) {
                    if (kr.getRequiredKnowledge() != null) {
                        rk.add(ref(kr.getRequiredKnowledge(), ids));
                    }
                }
                bn.set("logic", expr(bkm.getEncapsulatedLogic()));
            } else if (e instanceof DecisionService ds) {
                if (!services.contains(ds)) {
                    services.add(ds);
                }
            } else if (e instanceof KnowledgeSource ks) {
                kss.add(ks.getName());
            }
        }
        for (DecisionService ds : services) {
            ObjectNode so = dss.addObject();
            so.put("name", ds.getName());
            so.put("id", ds.getId());
            so.set("outputDecisions", refs(ds.getOutputDecision(), ids));
            so.set("encapsulatedDecisions", refs(ds.getEncapsulatedDecision(), ids));
            so.set("inputDecisions", refs(ds.getInputDecision(), ids));
            so.set("inputData", refs(ds.getInputData(), ids));
        }
        o.set("messages", msgs);
        return o;
    }

    private ModelSet.LoadedFile importedFile(Import i) {
        ModelSet.LoadedFile hit = null;
        for (ModelSet.LoadedFile f : ms.files) {
            if (f.defs != null && i.getNamespace() != null && i.getNamespace().equals(f.defs.getNamespace())) {
                String mn = i.getAdditionalAttributes().get(new QName("http://www.drools.org/kie/dmn/1.2", "modelName"));
                if (mn == null || mn.equals(f.defs.getName())) {
                    if (hit == null || f.round < hit.round) {
                        hit = f;
                    }
                }
            }
        }
        return hit;
    }

    private static Map<String, String> idIndex(Definitions d, String hrefPrefix) {
        return idIndex(d, hrefPrefix, "");
    }

    private static Map<String, String> idIndex(Definitions d, String hrefPrefix, String namePrefix) {
        Map<String, String> m = new HashMap<>();
        for (DRGElement e : d.getDrgElement()) {
            m.put(hrefPrefix + e.getId(), namePrefix + e.getName());
        }
        for (DecisionService ds : d.getDecisionService()) {
            m.put(hrefPrefix + ds.getId(), namePrefix + ds.getName());
        }
        return m;
    }

    private static String ref(DMNElementReference r, Map<String, String> ids) {
        String href = r.getHref();
        if (href == null) {
            return null;
        }
        String key = href.startsWith("#") ? href.substring(1) : href;
        String n = ids.get(key);
        return n != null ? n : "?" + href;
    }

    private static ArrayNode refs(List<DMNElementReference> rs, Map<String, String> ids) {
        ArrayNode a = F.arrayNode();
        if (rs != null) {
            rs.forEach(r -> a.add(ref(r, ids)));
        }
        return a;
    }

    static String typeRef(InformationItem v) {
        if (v == null || v.getTypeRef() == null) {
            return null;
        }
        return qn(v.getTypeRef());
    }

    static String qn(QName q) {
        if (q == null) {
            return null;
        }
        return (q.getPrefix() != null && !q.getPrefix().isEmpty() ? q.getPrefix() + ":" : "") + q.getLocalPart();
    }

    static ObjectNode type(DMNType t) {
        if (t == null) {
            return null;
        }
        ObjectNode o = F.objectNode();
        o.put("name", t.getName());
        o.put("namespace", t.getNamespace());
        o.put("collection", t.isCollection());
        o.put("composite", t.isComposite());
        org.kie.dmn.feel.lang.types.BuiltInType bt = Json.builtIn(t);
        if (bt != null) {
            o.put("feel", bt.getName());
        }
        if (t.isComposite()) {
            ObjectNode fs = o.putObject("fields");
            t.getFields().forEach((k, v) -> fs.put(k, v == null ? null : v.getName() + (v.isCollection() ? "[]" : "")));
        }
        return o;
    }

    static ObjectNode expr(Expression e) {
        if (e == null) {
            ObjectNode o = F.objectNode();
            o.put("kind", "none");
            return o;
        }
        ObjectNode o = F.objectNode();
        if (e.getTypeRef() != null) {
            o.put("typeRef", qn(e.getTypeRef()));
        }
        if (e instanceof DecisionTable dt) {
            o.put("kind", "decisionTable");
            o.put("hitPolicy", dt.getHitPolicy() == null ? "UNIQUE" : dt.getHitPolicy().name());
            if (dt.getAggregation() != null) {
                o.put("aggregation", dt.getAggregation().name());
            }
            ArrayNode ins = o.putArray("inputs");
            for (InputClause ic : dt.getInput()) {
                ins.add(ic.getInputExpression() == null ? null : ic.getInputExpression().getText());
            }
            ArrayNode outs = o.putArray("outputs");
            for (OutputClause oc : dt.getOutput()) {
                ObjectNode oo = outs.addObject();
                oo.put("name", oc.getName());
                oo.put("typeRef", qn(oc.getTypeRef()));
            }
            o.put("rules", dt.getRule().size());
        } else if (e instanceof LiteralExpression le) {
            o.put("kind", "literalExpression");
            o.put("text", le.getText());
        } else if (e instanceof Context c) {
            o.put("kind", "context");
            ArrayNode es = o.putArray("entries");
            for (ContextEntry ce : c.getContextEntry()) {
                ObjectNode eo = es.addObject();
                eo.put("name", ce.getVariable() == null ? null : ce.getVariable().getName());
                eo.set("value", expr(ce.getExpression()));
            }
        } else if (e instanceof Invocation inv) {
            o.put("kind", "invocation");
            o.put("function", inv.getExpression() instanceof LiteralExpression le ? le.getText() : null);
            ArrayNode bs = o.putArray("bindings");
            inv.getBinding().forEach(b -> bs.add(b.getParameter() == null ? null : b.getParameter().getName()));
        } else if (e instanceof org.kie.dmn.model.api.List l) {
            o.put("kind", "list");
            ArrayNode items = o.putArray("items");
            l.getExpression().forEach(x -> items.add(expr(x)));
        } else if (e instanceof Relation r) {
            o.put("kind", "relation");
            ArrayNode cols = o.putArray("columns");
            r.getColumn().forEach(c -> cols.add(c.getName()));
            o.put("rows", r.getRow().size());
        } else if (e instanceof FunctionDefinition fd) {
            o.put("kind", "functionDefinition");
            o.put("functionKind", fd.getKind() == null ? "FEEL" : fd.getKind().name());
            ArrayNode ps = o.putArray("parameters");
            fd.getFormalParameter().forEach(p -> ps.add(p.getName()));
            o.set("body", expr(fd.getExpression()));
        } else if (e instanceof Conditional) {
            o.put("kind", "conditional");
        } else if (e instanceof Filter) {
            o.put("kind", "filter");
        } else if (e instanceof Iterator) {
            o.put("kind", e.getClass().getSimpleName().replaceFirst("^T", "").toLowerCase());
        } else {
            o.put("kind", e.getClass().getSimpleName());
        }
        return o;
    }
}
