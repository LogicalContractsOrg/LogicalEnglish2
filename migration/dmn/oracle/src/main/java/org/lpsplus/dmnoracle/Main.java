package org.lpsplus.dmnoracle;

import java.io.InputStream;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;

/**
 * dmn-oracle: a headless harness on Apache KIE Drools DMN.
 *
 *   eval --models <file-or-dir>... --cases cases.json [--out results.json]
 *   drg  --models <file-or-dir>... [--out drg.json] [--summary]
 *   tck  <TestCases dir> [--out tck-results.json]
 *
 * Common options: --normalise, --no-typecheck, --extended-profile, --log <error|warn|info|debug>.
 */
public final class Main {

    private static final String USAGE = String.join("\n",
            "usage: java -jar dmn-oracle.jar <command> [options]",
            "  eval --models <file-or-dir>... --cases cases.json [--out results.json]",
            "  drg  --models <file-or-dir>... [--out drg.json] [--summary]",
            "  tck  <TestCases dir> [--out tck-results.json]",
            "options: --normalise  --no-typecheck  --extended-profile  --log <error|warn|info|debug>",
            "  (without --out, JSON goes to standard output)");

    public static void main(String[] args) throws Exception {
        if (args.length == 0 || args[0].equals("-h") || args[0].equals("--help")) {
            System.err.println(USAGE);
            System.exit(args.length == 0 ? 2 : 0);
        }
        String cmd = args[0];
        List<String> models = new ArrayList<>();
        List<String> positional = new ArrayList<>();
        String cases = null, out = null, log = "off";
        boolean summary = false;
        ModelSet.Options opt = new ModelSet.Options();
        for (int i = 1; i < args.length; i++) {
            String a = args[i];
            switch (a) {
                case "--models", "--model" -> {
                    while (i + 1 < args.length && !args[i + 1].startsWith("--")) {
                        models.add(args[++i]);
                    }
                }
                case "--cases" -> cases = args[++i];
                case "--out" -> out = args[++i];
                case "--log" -> log = args[++i];
                case "--summary" -> summary = true;
                case "--normalise", "--normalize" -> opt.normalise = true;
                case "--no-typecheck" -> opt.typeCheck = false;
                case "--extended-profile" -> opt.extendedProfile = true;
                default -> {
                    if (a.startsWith("--")) {
                        die("unknown option " + a);
                    }
                    positional.add(a);
                }
            }
        }
        System.setProperty("org.slf4j.simpleLogger.defaultLogLevel", log);
        System.setProperty("org.slf4j.simpleLogger.logFile", "System.err");
        switch (cmd) {
            case "eval" -> {
                if (models.isEmpty() || cases == null) {
                    die("eval needs --models and --cases");
                }
                long t0 = System.nanoTime();
                ModelSet ms = ModelSet.load(ModelSet.collect(models), opt);
                long t1 = System.nanoTime();
                JsonNode cs = Json.MAPPER.readTree(Files.readString(Path.of(cases), StandardCharsets.UTF_8));
                ArrayNode res = new Eval(ms).run(cs);
                long t2 = System.nanoTime();
                System.err.printf("dmn-oracle: %d file(s) loaded in %.2f s, %d case(s) evaluated in %.2f s%n",
                                  ms.files.size(), (t1 - t0) / 1e9, res.size(), (t2 - t1) / 1e9);
                write(res, out);
            }
            case "drg" -> {
                if (models.isEmpty()) {
                    models.addAll(positional);
                }
                if (models.isEmpty()) {
                    die("drg needs --models");
                }
                ModelSet ms = ModelSet.load(ModelSet.collect(models), opt);
                Drg drg = new Drg(ms);
                ArrayNode a = Json.F.arrayNode();
                int ok = 0;
                for (ModelSet.LoadedFile lf : ms.files) {
                    var d = drg.describe(lf);
                    a.add(d);
                    if (d.path("compiled").asBoolean()) {
                        ok++;
                    }
                    if (summary) {
                        System.err.printf("%-8s %s%n", d.path("compiled").asBoolean() ? "OK" : "ERRORS", lf.path);
                    }
                }
                System.err.printf("dmn-oracle: %d of %d model file(s) compiled without errors%n", ok, ms.files.size());
                write(a, out);
            }
            case "tck" -> {
                if (positional.isEmpty()) {
                    die("tck needs the TestCases directory");
                }
                PrintStream ps = System.out;
                var res = new Tck(opt).run(Path.of(positional.get(0)), ps);
                if (out != null) {
                    write(res, out);
                }
            }
            case "version" -> System.out.println("dmn-oracle " + prop("oracle.version") + " on Apache KIE Drools DMN " + droolsVersion());
            default -> die("unknown command " + cmd);
        }
    }

    static void write(JsonNode n, String out) throws Exception {
        String s = Json.MAPPER.writeValueAsString(n) + "\n";
        if (out == null || out.equals("-")) {
            System.out.print(s);
            System.out.flush();
        } else {
            Files.writeString(Path.of(out), s, StandardCharsets.UTF_8);
        }
    }

    static String droolsVersion() {
        return prop("drools.version");
    }

    private static String prop(String k) {
        try (InputStream in = Main.class.getResourceAsStream("/dmn-oracle.properties")) {
            Properties p = new Properties();
            p.load(in);
            return p.getProperty(k);
        } catch (Exception e) {
            return "?";
        }
    }

    private static void die(String m) {
        System.err.println("dmn-oracle: " + m);
        System.err.println(USAGE);
        System.exit(2);
    }
}
