package le.drools;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.kie.api.KieServices;
import org.kie.api.builder.KieBuilder;
import org.kie.api.builder.KieFileSystem;
import org.kie.api.builder.Message;
import org.kie.api.definition.type.FactType;
import org.kie.api.event.rule.*;
import org.kie.api.runtime.KieContainer;
import org.kie.api.runtime.KieSession;

import java.io.File;
import java.lang.reflect.*;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

/**
 * The Drools oracle of the DRL -> Logical English translator (LE2
 * migration/drools, Phase 2e): a real KieSession runs a rule base on a
 * working memory, and the rules that fired are reported in order, each with
 * the facts it inserted, updated and deleted — what the Logical English twin
 * is checked against.
 *
 *   java -jar drl-oracle.jar spec.json
 *
 * spec: { "drl": ["rules.drl", ...], "classes": "dir of compiled fact classes" (optional),
 *         "facts": [ {"declared": "pkg.Type", "fields": {...}}
 *                  | {"class": "pkg.Class", "args": [...]}
 *                  | {"class": "pkg.Class", "fields": {...}} ],
 *         "steps": [{"insert": [facts], "delete": [ids]}, ...] (optional: what a
 *                  Java driver does between two fireAllRules),
 *         "maxFirings": 1000 }
 * reply: { "firings": [{"rule": name, "inserted": [..], "updated": [..], "deleted": [..]}],
 *          "final": [facts], "errors": [...] }
 * A fact is written {"type": simple class name, "fields": {name: value}}.
 */
public class DrlOracle {
    static final ObjectMapper M = new ObjectMapper();

    static java.io.PrintStream OUT = System.out;

    public static void main(String[] args) throws Exception {
        //  the rules' own System.out.println goes to stderr: stdout is the reply
        OUT = System.out; System.setOut(System.err);
        if (args.length > 1 && args[0].equals("describe")) { describe(args); return; }
        JsonNode spec = M.readTree(new File(args[0]));
        ObjectNode reply = M.createObjectNode();
        ArrayNode errors = reply.putArray("errors");
        ClassLoader cl = DrlOracle.class.getClassLoader();
        if (spec.hasNonNull("classes")) {
            List<URL> urls = new ArrayList<>();
            for (String c : spec.get("classes").asText().split(File.pathSeparator)) urls.add(new File(c).toURI().toURL());
            cl = new URLClassLoader(urls.toArray(new URL[0]), cl);
        }
        KieServices ks = KieServices.Factory.get();
        KieFileSystem kfs = ks.newKieFileSystem();
        int i = 0;
        for (JsonNode d : spec.get("drl")) {
            String text = Files.readString(Path.of(d.asText()));
            kfs.write("src/main/resources/rules/r" + (i++) + ".drl", ks.getResources().newByteArrayResource(text.getBytes("UTF-8")));
        }
        KieBuilder kb = ks.newKieBuilder(kfs, cl);
        kb.buildAll();
        boolean broken = false;
        for (Message m : kb.getResults().getMessages()) {
            if (m.getLevel() == Message.Level.ERROR) broken = true;
            errors.add(m.getLevel() + ": " + m.getText() + " (line " + m.getLine() + ")");
        }
        if (broken) { OUT.println(M.writerWithDefaultPrettyPrinter().writeValueAsString(reply)); return; }
        KieContainer kc = ks.newKieContainer(ks.getRepository().getDefaultReleaseId(), cl);
        KieSession session = kc.newKieSession();
        ArrayNode firings = reply.putArray("firings");
        final ObjectNode[] current = {null};
        session.addEventListener(new DefaultAgendaEventListener() {
            @Override public void beforeMatchFired(BeforeMatchFiredEvent e) {
                ObjectNode f = firings.addObject();
                f.put("rule", e.getMatch().getRule().getName());
                f.putArray("inserted"); f.putArray("updated"); f.putArray("deleted");
                current[0] = f;
            }
            @Override public void afterMatchFired(AfterMatchFiredEvent e) { current[0] = null; }
        });
        session.addEventListener(new DefaultRuleRuntimeEventListener() {
            @Override public void objectInserted(ObjectInsertedEvent e) { note("inserted", e.getObject()); }
            @Override public void objectUpdated(ObjectUpdatedEvent e) { note("updated", e.getObject()); }
            @Override public void objectDeleted(ObjectDeletedEvent e) { note("deleted", e.getOldObject()); }
            void note(String kind, Object o) { if (current[0] != null) ((ArrayNode) current[0].get(kind)).add(fact(o)); }
        });
        //  facts in order; one with an "id" can be an argument of a later one
        //  ({"ref": id}), which is how a Sprinkler gets its Room
        Map<String, Object> byId = new HashMap<>();
        Map<String, org.kie.api.runtime.rule.FactHandle> handles = new HashMap<>();
        for (JsonNode f : spec.path("facts")) {
            try {
                Object o = make(f, kc, cl, byId);
                if (f.hasNonNull("id")) byId.put(f.get("id").asText(), o);
                if (!f.path("hidden").asBoolean(false)) {
                    org.kie.api.runtime.rule.FactHandle h = session.insert(o);
                    if (f.hasNonNull("id")) handles.put(f.get("id").asText(), h);
                }
            }
            catch (Exception ex) { errors.add("fact " + f + ": " + ex); }
        }
        int max = spec.path("maxFirings").asInt(1000);
        try { session.fireAllRules(max); } catch (Exception ex) { errors.add("run: " + ex); }
        //  later steps: facts inserted or deleted from outside (as a Java
        //  driver does between two fireAllRules), each followed by a run; the
        //  firings of step k carry "step": k
        int step = 1;
        for (JsonNode st : spec.path("steps")) {
            final int k = step++;
            for (JsonNode f : st.path("insert")) {
                try {
                    Object o = make(f, kc, cl, byId);
                    if (f.hasNonNull("id")) byId.put(f.get("id").asText(), o);
                    handles.put(f.path("id").asText(null), session.insert(o));
                } catch (Exception ex) { errors.add("step " + k + " fact " + f + ": " + ex); }
            }
            for (JsonNode d : st.path("delete")) {
                org.kie.api.runtime.rule.FactHandle h = handles.get(d.asText());
                if (h == null) {
                    Object o = byId.get(d.asText());
                    if (o != null) h = session.getFactHandle(o);
                }
                if (h != null) session.delete(h); else errors.add("step " + k + ": no fact " + d);
            }
            int before = firings.size();
            try { session.fireAllRules(max); } catch (Exception ex) { errors.add("run: " + ex); }
            for (int j = before; j < firings.size(); j++) ((ObjectNode) firings.get(j)).put("step", k);
        }
        ArrayNode fin = reply.putArray("final");
        List<ObjectNode> finals = new ArrayList<>();
        for (Object o : session.getObjects()) finals.add(fact(o));
        finals.sort(Comparator.comparing(ObjectNode::toString));
        finals.forEach(fin::add);
        session.dispose();
        OUT.println(M.writerWithDefaultPrettyPrinter().writeValueAsString(reply));
    }

    /* A fact of the spec: a declared type (by its FactType) or a class of
       the model (a constructor taking the args, or setters for the fields). */
    static Object make(JsonNode f, KieContainer kc, ClassLoader cl, Map<String, Object> byId) throws Exception {
        if (f.has("declared")) {
            String full = f.get("declared").asText();
            int dot = full.lastIndexOf('.');
            FactType t = kc.getKieBase().getFactType(full.substring(0, dot), full.substring(dot + 1));
            if (t == null) throw new IllegalArgumentException("no declared type " + full);
            Object o = t.newInstance();
            for (Iterator<String> it = f.path("fields").fieldNames(); it.hasNext(); ) {
                String n = it.next();
                Class<?> ft = t.getField(n).getType();
                t.set(o, n, value(f.get("fields").get(n), ft, byId));
            }
            return o;
        }
        Class<?> c = Class.forName(f.get("class").asText(), true, cl);
        if (f.has("args")) {
            JsonNode a = f.get("args");
            for (Constructor<?> k : c.getConstructors()) {
                if (k.getParameterCount() != a.size()) continue;
                Object[] vs = new Object[a.size()];
                Class<?>[] ps = k.getParameterTypes();
                try {
                    for (int j = 0; j < vs.length; j++) vs[j] = value(a.get(j), ps[j], byId);
                    return k.newInstance(vs);
                } catch (IllegalArgumentException ignored) { }
            }
            throw new IllegalArgumentException("no constructor of " + c.getName() + " takes " + a);
        }
        Object o = c.getConstructor().newInstance();
        for (Iterator<String> it = f.path("fields").fieldNames(); it.hasNext(); ) {
            String n = it.next();
            Method s = setter(c, n);
            s.invoke(o, value(f.get("fields").get(n), s.getParameterTypes()[0], byId));
        }
        return o;
    }

    static Method setter(Class<?> c, String n) {
        String sn = "set" + Character.toUpperCase(n.charAt(0)) + n.substring(1);
        for (Method m : c.getMethods()) if (m.getName().equals(sn) && m.getParameterCount() == 1) return m;
        throw new IllegalArgumentException("no setter " + sn + " in " + c.getName());
    }

    static Object value(JsonNode v, Class<?> t, Map<String, Object> byId) {
        if (v.isObject() && v.has("ref")) {
            Object o = byId.get(v.get("ref").asText());
            if (o == null || !t.isInstance(o)) throw new IllegalArgumentException("ref " + v);
            return o;
        }
        if (t == int.class || t == Integer.class) { if (!v.isNumber()) throw new IllegalArgumentException(); return v.asInt(); }
        if (t == long.class || t == Long.class) { if (!v.isNumber()) throw new IllegalArgumentException(); return v.asLong(); }
        if (t == double.class || t == Double.class) { if (!v.isNumber()) throw new IllegalArgumentException(); return v.asDouble(); }
        if (t == boolean.class || t == Boolean.class) { if (!v.isBoolean()) throw new IllegalArgumentException(); return v.asBoolean(); }
        if (t == String.class) { if (!v.isTextual()) throw new IllegalArgumentException(); return v.asText(); }
        if (t.isEnum()) { for (Object e : t.getEnumConstants()) if (e.toString().equals(v.asText())) return e; throw new IllegalArgumentException(); }
        if (t == Object.class) return v.isNumber() ? (Object) v.numberValue() : v.isBoolean() ? v.asBoolean() : v.asText();
        throw new IllegalArgumentException("unsupported field type " + t);
    }

    /* describe <classesDir> <class>...: each class's properties in its
       declaration order (the field order of its fluent), with their types —
       the fact model a DRL rule base is written against. */
    static void describe(String[] args) throws Exception {
        ClassLoader cl = new URLClassLoader(new URL[]{new File(args[1]).toURI().toURL()}, DrlOracle.class.getClassLoader());
        ObjectNode out = M.createObjectNode();
        for (int i = 2; i < args.length; i++) {
            Class<?> c = Class.forName(args[i], true, cl);
            ArrayNode fs = out.putArray(c.getSimpleName());
            for (Field f : c.getDeclaredFields()) {
                if (Modifier.isStatic(f.getModifiers())) continue;
                ObjectNode d = fs.addObject();
                d.put("name", f.getName());
                d.put("type", f.getType().isPrimitive() || f.getType().getName().startsWith("java.") ? f.getType().getSimpleName() : "object:" + f.getType().getSimpleName());
            }
        }
        OUT.println(M.writerWithDefaultPrettyPrinter().writeValueAsString(out));
    }

    /* A fact as {"type", "fields"}: its bean properties (getters), or its
       public fields. */
    static ObjectNode fact(Object o) {
        ObjectNode n = M.createObjectNode();
        n.put("type", o.getClass().getSimpleName());
        ObjectNode fs = n.putObject("fields");
        for (Method m : o.getClass().getMethods()) {
            String name = m.getName();
            if (m.getParameterCount() != 0 || m.getDeclaringClass() == Object.class) continue;
            String p = null;
            if (name.startsWith("get") && name.length() > 3 && !name.equals("getClass")) p = name.substring(3);
            else if (name.startsWith("is") && name.length() > 2 && (m.getReturnType() == boolean.class)) p = name.substring(2);
            if (p == null) continue;
            p = Character.toLowerCase(p.charAt(0)) + p.substring(1);
            try { put(fs, p, m.invoke(o)); } catch (Exception ignored) { }
        }
        return n;
    }

    static void put(ObjectNode fs, String p, Object v) {
        if (v == null) fs.putNull(p);
        else if (v instanceof Integer || v instanceof Long || v instanceof Short) fs.put(p, ((Number) v).longValue());
        else if (v instanceof Number) fs.put(p, ((Number) v).doubleValue());
        else if (v instanceof Boolean) fs.put(p, (Boolean) v);
        else if (v instanceof String || v instanceof Enum || v instanceof Character) fs.put(p, v.toString());
        else {
            //  an object: by its name (or id), which is how the twin keys it
            for (String k : new String[]{"getName", "getId"}) {
                try { Object n = v.getClass().getMethod(k).invoke(v); if (n != null) { fs.put(p, n.toString()); return; } }
                catch (Exception ignored) { }
            }
            fs.put(p, v.getClass().getSimpleName() + ":" + System.identityHashCode(v));
        }
    }
}
