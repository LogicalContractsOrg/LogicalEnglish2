package org.lpsplus.dmnoracle;

import java.io.StringReader;
import java.io.StringWriter;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.xml.sax.InputSource;

/**
 * In-memory rewrites applied with --normalise. The file on disk is never changed. Each rewrite that fires is
 * recorded (drg prints them under "normalisations"). The rewrites are for the dialect of Camunda Modeler, which
 * accepts DMN that the standard (and Drools) rejects:
 *
 *  1. missing-variable: a decision, input data or business knowledge model without a &lt;variable&gt; gets one, named
 *     like the element; its typeRef is the element's single decision-table output typeRef or its literal expression
 *     typeRef, when there is one, else none.
 *  2. java-typeRef: typeRef="integer" | "long" | "int" | "short" | "double" | "float" | "decimal" (not FEEL type names,
 *     Camunda maps them to Java types) becomes typeRef="number", unless the model defines an itemDefinition of that name.
 *  3. empty-input-entry: a decision-table input entry with empty text becomes "-" (any value), which is what Camunda
 *     means by it.
 *  4. missing-requirement (only in files exported by Camunda Modeler or declaring the camunda namespace; elsewhere it
 *     changed two DMN TCK results): a decision whose expression texts mention, as a whole word, the name of an input data or
 *     of another decision of the same model, without an information requirement for it, gets one (Camunda resolves
 *     such names from the process variables and does not need the link; Drools does).
 *
 * Nothing else is touched. The STTR "${oin}" namespace placeholder needs no rewrite: Drools 10.2 loads it as is.
 */
public final class Normaliser {

    private static final Set<String> JAVA_NUMBER_TYPES = Set.of("integer", "long", "int", "short", "double", "float", "decimal");

    private Normaliser() {
    }

    public static String normalise(String text, List<String> applied) {
        try {
            DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
            dbf.setNamespaceAware(true);
            Document doc = dbf.newDocumentBuilder().parse(new InputSource(new StringReader(text)));
            Element root = doc.getDocumentElement();
            String ns = root.getNamespaceURI();
            if (ns == null || !ns.contains("/spec/DMN/") || !"definitions".equals(root.getLocalName())) {
                return text;
            }
            List<String> done = new ArrayList<>();
            Set<String> itemDefs = new HashSet<>();
            for (Element e : Tck.children(root, "itemDefinition")) {
                itemDefs.add(e.getAttribute("name"));
            }
            int vars = 0, types = 0, entries = 0;
            for (Element e : all(root)) {
                if (!ns.equals(e.getNamespaceURI())) {
                    continue;
                }
                String ln = e.getLocalName();
                if ((ln.equals("decision") || ln.equals("inputData") || ln.equals("businessKnowledgeModel"))
                        && e.getParentNode() == root && Tck.child(e, "variable") == null) {
                    Element v = doc.createElementNS(ns, qualified(e, "variable"));
                    v.setAttribute("id", (e.getAttribute("id").isEmpty() ? "v" : e.getAttribute("id")) + "_variable");
                    v.setAttribute("name", e.getAttribute("name"));
                    String tr = guessTypeRef(e);
                    if (tr != null && JAVA_NUMBER_TYPES.contains(tr) && !itemDefs.contains(tr)) {
                        tr = "number";
                    }
                    if (tr != null) {
                        v.setAttribute("typeRef", tr);
                    }
                    Node before = null;
                    for (Node c = e.getFirstChild(); c != null; c = c.getNextSibling()) {
                        if (c instanceof Element ce && !Set.of("description", "extensionElements", "question", "allowedAnswers").contains(ce.getLocalName())) {
                            before = c;
                            break;
                        }
                    }
                    e.insertBefore(v, before);
                    vars++;
                }
                if (e.hasAttribute("typeRef")) {
                    String tr = e.getAttribute("typeRef");
                    if (JAVA_NUMBER_TYPES.contains(tr) && !itemDefs.contains(tr)) {
                        e.setAttribute("typeRef", "number");
                        types++;
                    }
                }
                if (ln.equals("inputEntry")) {
                    Element t = Tck.child(e, "text");
                    if (t == null) {
                        t = doc.createElementNS(ns, qualified(e, "text"));
                        e.appendChild(t);
                    }
                    if (t.getTextContent().trim().isEmpty()) {
                        t.setTextContent("-");
                        entries++;
                    }
                }
            }
            boolean camunda = root.getAttribute("exporter").toLowerCase().contains("camunda") || text.contains("http://camunda.org/schema/");
            int reqs = camunda ? addMissingRequirements(doc, root, ns) : 0;
            if (reqs > 0) {
                done.add("missing-requirement: added " + reqs + " <informationRequirement>(s)");
            }
            if (vars > 0) {
                done.add("missing-variable: added " + vars + " <variable> declaration(s)");
            }
            if (types > 0) {
                done.add("java-typeRef: " + types + " typeRef(s) integer/long/double/... -> number");
            }
            if (entries > 0) {
                done.add("empty-input-entry: " + entries + " empty decision-table input entr(y/ies) -> \"-\"");
            }
            if (done.isEmpty()) {
                return text;
            }
            applied.addAll(done);
            Transformer tf = TransformerFactory.newDefaultInstance().newTransformer();
            StringWriter w = new StringWriter();
            tf.transform(new DOMSource(doc), new StreamResult(w));
            return w.toString();
        } catch (Exception e) {
            applied.add("normalisation skipped: " + ModelSet.oneLine(e));
            return text;
        }
    }

    private static int addMissingRequirements(Document doc, Element root, String ns) {
        java.util.Map<String, Element> byName = new java.util.LinkedHashMap<>();
        for (Node c = root.getFirstChild(); c != null; c = c.getNextSibling()) {
            if (c instanceof Element e && ns.equals(e.getNamespaceURI())
                    && (e.getLocalName().equals("inputData") || e.getLocalName().equals("decision"))
                    && !e.getAttribute("name").isEmpty() && !e.getAttribute("id").isEmpty()) {
                byName.putIfAbsent(e.getAttribute("name"), e);
            }
        }
        int added = 0;
        for (Element d : new ArrayList<>(byName.values())) {
            if (!d.getLocalName().equals("decision")) {
                continue;
            }
            Set<String> have = new HashSet<>();
            for (Element ir : Tck.children(d, "informationRequirement")) {
                for (Element r : java.util.Arrays.asList(Tck.child(ir, "requiredInput"), Tck.child(ir, "requiredDecision"))) {
                    if (r == null) {
                        continue;
                    }
                    String h = r.getAttribute("href");
                    have.add(h.substring(h.indexOf('#') + 1));
                }
            }
            StringBuilder texts = new StringBuilder();
            for (Element e : all(d)) {
                if (e.getLocalName() != null && e.getLocalName().equals("text")) {
                    texts.append(' ').append(e.getTextContent()).append(' ');
                }
            }
            String t = texts.toString();
            for (Element target : byName.values()) {
                if (target == d || have.contains(target.getAttribute("id"))) {
                    continue;
                }
                String name = target.getAttribute("name");
                java.util.regex.Pattern p = java.util.regex.Pattern.compile("(?<![\\p{L}\\p{N}_.\"])" + java.util.regex.Pattern.quote(name) + "(?![\\p{L}\\p{N}_\"])");
                if (!p.matcher(t).find()) {
                    continue;
                }
                Element ir = doc.createElementNS(ns, qualified(d, "informationRequirement"));
                ir.setAttribute("id", d.getAttribute("id") + "_req_" + target.getAttribute("id"));
                Element r = doc.createElementNS(ns, qualified(d, target.getLocalName().equals("decision") ? "requiredDecision" : "requiredInput"));
                r.setAttribute("href", "#" + target.getAttribute("id"));
                ir.appendChild(r);
                // informationRequirement comes after variable (and description, extensionElements, question, allowedAnswers)
                Node before = null;
                for (Node c = d.getFirstChild(); c != null; c = c.getNextSibling()) {
                    if (c instanceof Element ce && !Set.of("description", "extensionElements", "question", "allowedAnswers", "variable", "informationRequirement").contains(ce.getLocalName())) {
                        before = c;
                        break;
                    }
                }
                d.insertBefore(ir, before);
                have.add(target.getAttribute("id"));
                added++;
            }
        }
        return added;
    }

    private static String qualified(Element like, String local) {
        String p = like.getPrefix();
        return p == null || p.isEmpty() ? local : p + ":" + local;
    }

    private static String guessTypeRef(Element e) {
        Element dt = Tck.child(e, "decisionTable");
        if (dt != null) {
            List<Element> outs = Tck.children(dt, "output");
            if (outs.size() == 1 && outs.get(0).hasAttribute("typeRef")) {
                return outs.get(0).getAttribute("typeRef");
            }
            return null;
        }
        Element le = Tck.child(e, "literalExpression");
        if (le != null && le.hasAttribute("typeRef")) {
            return le.getAttribute("typeRef");
        }
        return null;
    }

    private static List<Element> all(Element root) {
        List<Element> out = new ArrayList<>();
        collect(root, out);
        return out;
    }

    private static void collect(Element e, List<Element> out) {
        out.add(e);
        for (Node c = e.getFirstChild(); c != null; c = c.getNextSibling()) {
            if (c instanceof Element ce) {
                collect(ce, out);
            }
        }
    }
}
