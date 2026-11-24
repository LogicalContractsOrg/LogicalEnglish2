package org.lpsplus.dmnoracle;

import java.io.File;
import java.io.IOException;
import java.io.PrintStream;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.OffsetTime;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

import javax.xml.datatype.DatatypeConstants;
import javax.xml.datatype.DatatypeFactory;
import javax.xml.datatype.Duration;
import javax.xml.datatype.XMLGregorianCalendar;
import javax.xml.parsers.DocumentBuilderFactory;

import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.kie.dmn.api.core.DMNContext;
import org.kie.dmn.api.core.DMNModel;
import org.kie.dmn.api.core.DMNResult;
import org.kie.dmn.api.core.DMNRuntime;
import org.kie.dmn.api.core.DMNType;
import org.kie.dmn.api.core.ast.DecisionNode;
import org.kie.dmn.api.core.ast.InputDataNode;
import org.kie.dmn.core.compiler.DMNTypeRegistryV15;
import org.kie.dmn.core.impl.BaseDMNTypeImpl;
import org.kie.dmn.core.impl.SimpleTypeImpl;
import org.kie.dmn.feel.lang.Type;
import org.kie.dmn.feel.lang.types.BuiltInType;
import org.kie.dmn.feel.lang.types.impl.ComparablePeriod;
import java.time.ZonedDateTime;
import org.kie.dmn.feel.util.NumberEvalHelper;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;

import static org.lpsplus.dmnoracle.Json.F;

/**
 * Runs DMN TCK test files the way the official Drools runner (runners/dmn-tck-runner-drools, DroolsTCKTest) does:
 * same model loading (main model + every .dmn in the folder), same value parsing (a port of parseType, on DOM
 * instead of JAXB) and the same comparison (CompareValuesUtil: numbers equal within 1e-8).
 *
 * DroolsTCKTest and CompareValuesUtil are files of the DMN TCK (https://github.com/dmn-tck/tck), licensed under the
 * Apache License, Version 2.0. The parts of this file that follow them are changed: they read the test file with
 * DOM, and they report results as JSON.
 */
public final class Tck {

    private static final String XSI = "http://www.w3.org/2001/XMLSchema-instance";
    private static final DMNTypeRegistryV15 REGISTRY = new DMNTypeRegistryV15(Collections.emptyMap());
    private static final BigDecimal PRECISION = new BigDecimal("0.00000001");

    private final ModelSet.Options options;
    int passed, failed, errors;

    public Tck(ModelSet.Options options) {
        this.options = options;
    }

    public ObjectNode run(Path testCasesDir, PrintStream out) throws Exception {
        List<Path> folders = new ArrayList<>();
        for (String level : new String[]{"compliance-level-2", "compliance-level-3"}) {
            Path p = testCasesDir.resolve(level);
            if (Files.isDirectory(p)) {
                try (Stream<Path> s = Files.list(p)) {
                    s.filter(Files::isDirectory).forEach(folders::add);
                }
            }
        }
        if (folders.isEmpty()) {   // a single compliance level, or a single test folder
            if (Files.list(testCasesDir).anyMatch(f -> f.getFileName().toString().matches(".*-test-\\d\\d.xml"))) {
                folders.add(testCasesDir);
            } else {
                try (Stream<Path> s = Files.list(testCasesDir)) {
                    s.filter(Files::isDirectory).forEach(folders::add);
                }
            }
        }
        folders.sort(null);
        ArrayNode all = F.arrayNode();
        long t0 = System.nanoTime();
        int evaluations = 0;
        for (Path folder : folders) {
            List<Path> tests;
            try (Stream<Path> s = Files.list(folder)) {
                tests = s.filter(f -> f.getFileName().toString().matches(".*-test-\\d\\d.xml")).sorted().toList();
            }
            for (Path tf : tests) {
                int p0 = passed, f0 = failed, e0 = errors;
                evaluations += runFile(folder, tf, all);
                out.printf("%-75s passed %3d  failed %3d  errors %3d%n",
                           folder.getParent().getFileName() + "/" + tf.getFileName(), passed - p0, failed - f0, errors - e0);
            }
        }
        double secs = (System.nanoTime() - t0) / 1e9;
        out.printf("TOTAL: %d cases, passed %d, failed %d, errors %d  (%.1f s)%n", passed + failed + errors, passed, failed, errors, secs);
        ObjectNode o = F.objectNode();
        o.put("engine", "Apache KIE Drools DMN " + Main.droolsVersion());
        o.put("passed", passed);
        o.put("failed", failed);
        o.put("errors", errors);
        o.put("seconds", secs);
        o.put("evaluations", evaluations);
        o.set("cases", all);
        return o;
    }

    private int runFile(Path folder, Path tf, ArrayNode all) throws Exception {
        DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
        dbf.setNamespaceAware(true);
        Document doc = dbf.newDocumentBuilder().parse(tf.toFile());
        Element root = doc.getDocumentElement();
        String modelName = text(child(root, "modelName"));
        Path modelPath = folder.resolve(modelName).toAbsolutePath().normalize();
        List<Element> testCases = children(root, "testCase");
        testCases.sort((a, b) -> a.getAttribute("id").compareTo(b.getAttribute("id")));
        String rel = folder.getParent().getFileName() + "/" + folder.getFileName();

        List<Path> paths = new ArrayList<>();
        paths.add(modelPath);
        try (Stream<Path> s = Files.walk(folder)) {
            s.filter(Files::isRegularFile).filter(f -> f.getFileName().toString().endsWith(".dmn"))
                    .map(f -> f.toAbsolutePath().normalize()).filter(f -> !f.equals(modelPath)).sorted().forEach(paths::add);
        }
        String loadError = null;
        DMNRuntime rt = null;
        DMNModel model = null;
        try {
            ModelSet ms = ModelSet.load(paths, options);
            ModelSet.LoadedFile main = ms.files.get(0);
            if (main.model == null) {
                loadError = "model did not compile: " + String.join("; ", main.loadErrors);
            } else {
                rt = main.runtime;
                model = main.model;
            }
        } catch (Throwable t) {
            loadError = ModelSet.oneLine(t);
        }
        int evaluations = 0;
        for (Element tc : testCases) {
            ObjectNode r = all.addObject();
            r.put("folder", rel);
            r.put("file", tf.getFileName().toString());
            r.put("id", tc.getAttribute("id"));
            ArrayNode failures = r.putArray("failures");
            ObjectNode actual = r.putObject("actual");
            if (loadError != null) {
                failures.add(loadError);
                r.put("status", "error");
                errors++;
                continue;
            }
            boolean exception = false;
            try {
                DMNContext ctx = rt.newContext();
                for (Element in : children(tc, "inputNode")) {
                    String name = in.getAttribute("name");
                    InputDataNode input = model.getInputByName(name);
                    DecisionNode decision = model.getDecisionByName(name);
                    if (input != null) {
                        ctx.set(name, parseTyped(in, input.getType(), "input node " + name));
                    } else if (decision != null) {
                        ctx.set(name, parseTyped(in, decision.getResultType(), "decision node " + name));
                    } else {
                        ctx.set(name, parseType(in, REGISTRY.unknown()));
                    }
                }
                DMNResult dsResult = null;
                boolean isDS = "decisionService".equals(tc.getAttribute("type"));
                for (Element rn : children(tc, "resultNode")) {
                    String name = rn.getAttribute("name");
                    try {
                        DMNResult res;
                        if (isDS) {
                            if (dsResult == null) {
                                dsResult = rt.evaluateDecisionService(model, ctx, tc.getAttribute("invocableName"));
                                evaluations++;
                            }
                            res = dsResult;
                        } else {
                            res = rt.evaluateByName(model, ctx, name);
                            evaluations++;
                        }
                        ctx = res.getContext();
                        DecisionNode dn = model.getDecisionByName(name);
                        Element expectedEl = child(rn, "expected");
                        if (expectedEl == null) {
                            throw new NullPointerException("resultNode '" + name + "' has no <expected>");
                        }
                        Object expected = parseTyped(expectedEl, dn == null ? null : dn.getResultType(), "input node " + name);
                        Object act = ctx.get(name);
                        actual.set(name, Json.toJson(act));
                        if (!areEqual(expected, act)) {
                            failures.add("'" + name + "' expected='" + expected + "' but found='" + act + "'");
                        }
                    } catch (Throwable t) {
                        exception = true;
                        failures.add("unexpected exception for '" + name + "': " + ModelSet.oneLine(t));
                    }
                }
            } catch (Throwable t) {
                exception = true;
                failures.add("unexpected exception: " + ModelSet.oneLine(t));
            }
            if (failures.isEmpty()) {
                r.put("status", "pass");
                passed++;
            } else if (exception) {
                r.put("status", "error");
                errors++;
            } else {
                r.put("status", "fail");
                failed++;
            }
        }
        return evaluations;
    }

    private Object parseTyped(Element v, DMNType t, String what) {
        if (t == null) {
            throw new RuntimeException("Unknown type for " + what);
        }
        return parseType(v, t);
    }

    // ---------------------------------------------------------------- a port of DroolsTCKTest.parseType

    /** What JAXB would have made of a valueType element. */
    private static final class Val {
        Element valueEl;        // <value>, or null
        boolean valueNil;
        Object typed;           // the xsi:type-converted value, or null
        boolean untyped;        // <value> without xsi:type: JAXB gives a DOM node
        List<Element> components = new ArrayList<>();
        Element listEl;
        boolean listNil;
    }

    private static Val val(Element e) {
        Val v = new Val();
        if (e == null) {
            return v;
        }
        v.valueEl = child(e, "value");
        v.components = children(e, "component");
        v.listEl = child(e, "list");
        if (v.listEl != null) {
            v.listNil = "true".equals(v.listEl.getAttributeNS(XSI, "nil"));
        }
        if (v.valueEl != null) {
            v.valueNil = "true".equals(v.valueEl.getAttributeNS(XSI, "nil"));
            String xt = v.valueEl.getAttributeNS(XSI, "type");
            String txt = v.valueEl.getTextContent();
            if (v.valueNil) {
                v.typed = null;
            } else if (xt == null || xt.isEmpty()) {
                v.untyped = true;
            } else {
                String local = xt.substring(xt.indexOf(':') + 1);
                v.typed = xsd(local, txt);
            }
        }
        return v;
    }

    private static Object xsd(String type, String txt) {
        try {
            DatatypeFactory df = DatatypeFactory.newInstance();
            String t = txt.trim();
            return switch (type) {
                case "string" -> txt;
                case "decimal", "integer", "int", "long" -> new BigDecimal(t);
                case "double", "float" -> Double.valueOf(t);
                case "boolean" -> Boolean.valueOf(t.equals("1") || t.equalsIgnoreCase("true"));
                case "date", "dateTime", "time" -> df.newXMLGregorianCalendar(t);
                case "duration" -> df.newDuration(t);
                default -> txt;
            };
        } catch (Exception e) {
            throw new RuntimeException("cannot read xsd:" + type + " value '" + txt + "': " + e.getMessage(), e);
        }
    }

    private Object parseType(Element el, DMNType dmnType) {
        Val value = val(el);
        if (value.listEl != null && !value.listNil) {
            List<Object> result = new ArrayList<>();
            for (Element item : children(value.listEl, "item")) {
                result.add(parseType(item, dmnType.isCollection() ? dmnType : REGISTRY.unknown()));
            }
            return result;
        } else if (isSimple(dmnType) || (isAny(dmnType) && value.valueEl != null && value.components.isEmpty())) {
            if (value.valueEl != null && !value.valueNil && value.untyped) {
                Node first = value.valueEl.getFirstChild();
                String text = first != null ? first.getTextContent() : null;
                if (text == null) {
                    return null;
                }
                if (isSimple(dmnType)) {
                    return builtIn((BaseDMNTypeImpl) dmnType).fromString(text);
                }
                return text;
            } else if (value.valueEl != null && !isDateTimeOrDuration(value.typed)) {
                return value.typed;
            } else {
                Object dt = value.valueEl != null ? value.typed : null;
                if (dt instanceof Duration || dt instanceof XMLGregorianCalendar) {
                    if (!isAny(dmnType)) {
                        String text = dt.toString();
                        return builtIn((BaseDMNTypeImpl) dmnType).fromString(text);
                    }
                    if (dt instanceof Duration) {
                        try {
                            return java.time.Duration.parse(dt.toString());
                        } catch (DateTimeParseException e) {
                            return ComparablePeriod.parse(dt.toString());
                        }
                    }
                    XMLGregorianCalendar c = (XMLGregorianCalendar) dt;
                    if (c.getTimezone() != DatatypeConstants.FIELD_UNDEFINED && c.getXMLSchemaType() == DatatypeConstants.DATETIME) {
                        return ZonedDateTime.parse(c.toXMLFormat()); // the runner at HEAD uses FormattedZonedDateTime, absent from 10.2.0
                    } else if (c.getTimezone() != DatatypeConstants.FIELD_UNDEFINED && c.getXMLSchemaType() == DatatypeConstants.TIME) {
                        return OffsetTime.parse(c.toXMLFormat());
                    } else if (c.getXMLSchemaType() == DatatypeConstants.DATETIME) {
                        return LocalDateTime.of(LocalDate.of(c.getYear(), c.getMonth(), c.getDay()), LocalTime.of(c.getHour(), c.getMinute(), c.getSecond()));
                    } else if (c.getXMLSchemaType() == DatatypeConstants.DATE) {
                        return LocalDate.of(c.getYear(), c.getMonth(), c.getDay());
                    } else if (c.getXMLSchemaType() == DatatypeConstants.TIME) {
                        return LocalTime.parse(c.toXMLFormat());
                    }
                    return c.toGregorianCalendar();
                }
                return null;
            }
        } else if (dmnType.isComposite() && !isAny(dmnType)) {
            if (value.components.isEmpty()) {
                return null;
            }
            Map<String, Object> result = new HashMap<>();
            for (Element comp : value.components) {
                String name = comp.getAttribute("name");
                DMNType ft = dmnType.getFields().get(name);
                if (!dmnType.getFields().containsKey(name)) {
                    ft = REGISTRY.unknown();
                }
                if (ft == null) {
                    throw new RuntimeException("Error parsing input: unknown type for field '" + name + "' on type " + dmnType.getName() + "'");
                }
                result.put(name, parseType(comp, ft));
            }
            return result;
        } else if (isAny(dmnType) && value.valueEl == null && !value.components.isEmpty()) {
            Map<String, Object> result = new HashMap<>();
            for (Element comp : value.components) {
                result.put(comp.getAttribute("name"), parseType(comp, REGISTRY.unknown()));
            }
            return result;
        } else {
            throw new RuntimeException("Unable to infer information from JAXB type");
        }
    }

    private static boolean isDateTimeOrDuration(Object v) {
        return v instanceof Duration || v instanceof XMLGregorianCalendar;
    }

    private static boolean isAny(DMNType t) {
        return ((BaseDMNTypeImpl) t).getFeelType().equals(BuiltInType.UNKNOWN);
    }

    private static boolean isSimple(DMNType t) {
        return !t.isComposite() && !isAny(t);
    }

    private static BuiltInType builtIn(BaseDMNTypeImpl t) {
        Type ft = t.getFeelType();
        if (ft instanceof BuiltInType bt) {
            return bt;
        } else if (t instanceof SimpleTypeImpl) {
            return builtIn((BaseDMNTypeImpl) t.getBaseType());
        }
        throw new RuntimeException("Unable to recurse to determine BuiltInType");
    }

    // ---------------------------------------------------------------- CompareValuesUtil

    @SuppressWarnings("unchecked")
    static boolean areEqual(Object a, Object b) {
        if (a == b) {
            return true;
        } else if (a == null || b == null) {
            return false;
        } else if (a instanceof Number && b instanceof Number) {
            BigDecimal x = NumberEvalHelper.getBigDecimalOrNull(a);
            BigDecimal y = NumberEvalHelper.getBigDecimalOrNull(b);
            return x.subtract(y).abs().compareTo(PRECISION) < 0;
        } else if (a instanceof List && b instanceof List) {
            List<Object> l1 = (List<Object>) a, l2 = (List<Object>) b;
            if (l1.size() != l2.size()) {
                return false;
            }
            for (int i = 0; i < l1.size(); i++) {
                if (!areEqual(l1.get(i), l2.get(i))) {
                    return false;
                }
            }
            return true;
        } else if (a instanceof Map && b instanceof Map) {
            Map<Object, Object> m1 = (Map<Object, Object>) a, m2 = (Map<Object, Object>) b;
            if (m1.size() != m2.size()) {
                return false;
            }
            for (Map.Entry<Object, Object> e : m1.entrySet()) {
                if (!areEqual(e.getValue(), m2.get(e.getKey()))) {
                    return false;
                }
            }
            return true;
        } else if (a instanceof String || b instanceof String) {
            return a.toString().equals(b.toString());
        } else if (!a.getClass().isAssignableFrom(b.getClass())) {
            return false;
        } else {
            return a.equals(b);
        }
    }

    // ---------------------------------------------------------------- DOM helpers

    static Element child(Element e, String local) {
        if (e == null) {
            return null;
        }
        for (Node n = e.getFirstChild(); n != null; n = n.getNextSibling()) {
            if (n instanceof Element c && local.equals(c.getLocalName())) {
                return c;
            }
        }
        return null;
    }

    static List<Element> children(Element e, String local) {
        List<Element> out = new ArrayList<>();
        if (e == null) {
            return out;
        }
        for (Node n = e.getFirstChild(); n != null; n = n.getNextSibling()) {
            if (n instanceof Element c && local.equals(c.getLocalName())) {
                out.add(c);
            }
        }
        return out;
    }

    static String text(Element e) {
        return e == null ? null : e.getTextContent().trim();
    }
}
