package org.lpsplus.dmnoracle;

import java.math.BigDecimal;
import java.math.BigInteger;
import java.time.Duration;
import java.time.chrono.ChronoPeriod;
import java.time.temporal.TemporalAccessor;
import java.time.temporal.TemporalQueries;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.kie.dmn.api.core.DMNType;
import org.kie.dmn.core.impl.BaseDMNTypeImpl;
import org.kie.dmn.core.impl.SimpleTypeImpl;
import org.kie.dmn.feel.runtime.FEELFunction;
import org.kie.dmn.feel.lang.Type;
import org.kie.dmn.feel.lang.types.BuiltInType;
import org.kie.dmn.feel.runtime.Range;
import org.kie.dmn.feel.runtime.impl.RangeImpl;
import org.kie.dmn.feel.runtime.impl.UndefinedValueComparable;
import org.kie.dmn.feel.util.TypeUtil;

/** JSON <-> FEEL value mapping. */
public final class Json {

    public static final ObjectMapper MAPPER = new ObjectMapper()
            .enable(DeserializationFeature.USE_BIG_DECIMAL_FOR_FLOATS)
            .enable(DeserializationFeature.USE_BIG_INTEGER_FOR_INTS)
            .enable(JsonGenerator.Feature.WRITE_BIGDECIMAL_AS_PLAIN)
            .enable(SerializationFeature.INDENT_OUTPUT);
    public static final JsonNodeFactory F = JsonNodeFactory.withExactBigDecimals(true);

    private Json() {
    }

    // ---------------------------------------------------------------- JSON -> FEEL

    /** Convert a JSON value to a FEEL value; the DMN type (may be null) only directs strings to dates etc. */
    public static Object toFeel(JsonNode n, DMNType type) {
        if (n == null || n.isNull() || n.isMissingNode()) {
            return null;
        }
        if (n.isNumber()) {
            if (n.isBigDecimal() || n.isFloatingPointNumber()) {
                return n.decimalValue();
            }
            return new BigDecimal(n.bigIntegerValue());
        }
        if (n.isBoolean()) {
            return n.booleanValue();
        }
        if (n.isTextual()) {
            String s = n.textValue();
            BuiltInType bt = builtIn(type);
            if (bt != null) {
                switch (bt) {
                    case DATE, TIME, DATE_TIME, DURATION -> {
                        Object v = bt.fromString(s);
                        return v != null ? v : s;
                    }
                    case NUMBER -> {
                        try {
                            return new BigDecimal(s);
                        } catch (NumberFormatException e) {
                            return s;
                        }
                    }
                    default -> {
                        return s;
                    }
                }
            }
            return s;
        }
        if (n.isArray()) {
            List<Object> out = new ArrayList<>();
            DMNType itemType = type != null && type.isCollection() ? itemType(type) : null;
            for (JsonNode e : n) {
                out.add(toFeel(e, itemType));
            }
            return out;
        }
        if (n.isObject()) {
            JsonNode t = n.get("@type");
            if (t != null && t.isTextual()) {
                return tagged(t.textValue(), n, type);
            }
            Map<String, Object> out = new LinkedHashMap<>();
            Map<String, DMNType> fields = type != null && type.isComposite() ? type.getFields() : Map.of();
            Iterator<Map.Entry<String, JsonNode>> it = n.fields();
            while (it.hasNext()) {
                Map.Entry<String, JsonNode> e = it.next();
                out.put(e.getKey(), toFeel(e.getValue(), fields.get(e.getKey())));
            }
            return out;
        }
        throw new IllegalArgumentException("unsupported JSON value: " + n);
    }

    private static DMNType itemType(DMNType collectionType) {
        // a collection ItemDefinition: Drools keeps the element structure on the same DMNType (fields) or on its base type
        if (collectionType.isComposite()) {
            return collectionType;
        }
        if (collectionType.getBaseType() != null) {
            return collectionType.getBaseType();
        }
        return collectionType;
    }

    private static Object tagged(String tag, JsonNode n, DMNType type) {
        String v = n.path("value").asText(null);
        switch (tag) {
            case "date":
                return BuiltInType.DATE.fromString(v);
            case "time":
                return BuiltInType.TIME.fromString(v);
            case "dateTime":
            case "date and time":
                return BuiltInType.DATE_TIME.fromString(v);
            case "duration":
                return BuiltInType.DURATION.fromString(v);
            case "number":
                return new BigDecimal(v);
            case "range": {
                Comparable lo = (Comparable) toFeel(n.get("start"), null);
                Comparable hi = (Comparable) toFeel(n.get("end"), null);
                boolean si = n.path("startIncluded").asBoolean(true);
                boolean ei = n.path("endIncluded").asBoolean(true);
                return new RangeImpl(si ? Range.RangeBoundary.CLOSED : Range.RangeBoundary.OPEN,
                                     lo == null ? new UndefinedValueComparable() : lo,
                                     hi == null ? new UndefinedValueComparable() : hi,
                                     ei ? Range.RangeBoundary.CLOSED : Range.RangeBoundary.OPEN);
            }
            default:
                throw new IllegalArgumentException("unknown @type '" + tag + "'");
        }
    }

    static BuiltInType builtIn(DMNType type) {
        if (!(type instanceof BaseDMNTypeImpl b)) {
            return null;
        }
        Type ft = b.getFeelType();
        if (ft instanceof BuiltInType bt) {
            return bt == BuiltInType.UNKNOWN ? null : bt;
        }
        if (type instanceof SimpleTypeImpl && type.getBaseType() != null && type.getBaseType() != type) {
            return builtIn(type.getBaseType());
        }
        return null;
    }

    // ---------------------------------------------------------------- FEEL -> JSON

    public static JsonNode toJson(Object v) {
        if (v == null) {
            return F.nullNode();
        }
        if (v instanceof BigDecimal bd) {
            return number(bd);
        }
        if (v instanceof BigInteger bi) {
            return F.numberNode(bi);
        }
        if (v instanceof Number num) {
            if (v instanceof Double d && (d.isNaN() || d.isInfinite())) {
                return F.textNode(d.toString());
            }
            return number(new BigDecimal(num.toString()));
        }
        if (v instanceof Boolean b) {
            return F.booleanNode(b);
        }
        if (v instanceof String s) {
            return F.textNode(s);
        }
        if (v instanceof Duration || v instanceof ChronoPeriod) {
            return typed("duration", TypeUtil.formatValue(v, false));
        }
        if (v instanceof TemporalAccessor ta) {
            boolean hasDate = ta.query(TemporalQueries.localDate()) != null;
            boolean hasTime = ta.query(TemporalQueries.localTime()) != null;
            String kind = hasDate && hasTime ? "dateTime" : hasDate ? "date" : "time";
            return typed(kind, TypeUtil.formatValue(v, false));
        }
        if (v instanceof Range r) {
            ObjectNode o = F.objectNode();
            o.put("@type", "range");
            boolean loUndef = r.getLowEndPoint() == null || r.getLowEndPoint() instanceof UndefinedValueComparable;
            boolean hiUndef = r.getHighEndPoint() == null || r.getHighEndPoint() instanceof UndefinedValueComparable;
            o.put("startIncluded", r.getLowBoundary() == Range.RangeBoundary.CLOSED);
            o.set("start", loUndef ? F.nullNode() : toJson(r.getLowEndPoint()));
            o.set("end", hiUndef ? F.nullNode() : toJson(r.getHighEndPoint()));
            o.put("endIncluded", r.getHighBoundary() == Range.RangeBoundary.CLOSED);
            o.put("feel", TypeUtil.formatValue(r, true));
            return o;
        }
        if (v instanceof Map<?, ?> m) {
            ObjectNode o = F.objectNode();
            for (Map.Entry<?, ?> e : m.entrySet()) {
                o.set(String.valueOf(e.getKey()), toJson(e.getValue()));
            }
            return o;
        }
        if (v instanceof Collection<?> c) {
            ArrayNode a = F.arrayNode();
            for (Object e : c) {
                a.add(toJson(e));
            }
            return a;
        }
        if (v instanceof Object[] arr) {
            ArrayNode a = F.arrayNode();
            for (Object e : arr) {
                a.add(toJson(e));
            }
            return a;
        }
        if (v instanceof FEELFunction f) {
            ObjectNode o = F.objectNode();
            o.put("@type", "function");
            o.put("name", f.getName());
            return o;
        }
        ObjectNode o = F.objectNode();
        o.put("@type", "unknown");
        o.put("class", v.getClass().getName());
        o.put("value", String.valueOf(v));
        return o;
    }

    private static JsonNode number(BigDecimal bd) {
        BigDecimal s = bd.signum() == 0 ? BigDecimal.ZERO : bd.stripTrailingZeros();
        if (s.scale() < 0) {
            s = s.setScale(0);
        }
        return F.numberNode(s);
    }

    private static ObjectNode typed(String kind, String value) {
        ObjectNode o = F.objectNode();
        o.put("@type", kind);
        o.put("value", value);
        return o;
    }
}
