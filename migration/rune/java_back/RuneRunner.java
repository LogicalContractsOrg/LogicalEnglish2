import com.google.inject.Injector;
import com.regnosys.rosetta.RosettaStandaloneSetup;
import com.regnosys.rosetta.generator.RosettaGenerator;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.util.EcoreUtil;
import org.eclipse.xtext.generator.GeneratorContext;
import org.eclipse.xtext.generator.IFileSystemAccess;
import org.eclipse.xtext.generator.JavaIoFileSystemAccess;
import org.eclipse.xtext.generator.OutputConfiguration;
import org.eclipse.xtext.resource.XtextResourceSet;
import org.eclipse.xtext.util.CancelIndicator;
import org.eclipse.xtext.validation.CheckMode;
import org.eclipse.xtext.validation.IResourceValidator;
import org.eclipse.xtext.validation.Issue;

import javax.tools.JavaCompiler;
import javax.tools.ToolProvider;
import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.List;
import java.util.jar.JarFile;
import java.util.jar.JarEntry;
import java.util.stream.Stream;

/**
 * The way back, kept warm (the design notes rune.md §13): one Java process
 * that loads DRR's and the CDM's Rune once, then, for each Rune file written
 * from Logical English, validates it with Rune's own validator, turns it
 * into Java with Rune's own generator, compiles it, and runs its report
 * function with DRR's Java on a test pack (DrrOracle.runPairs).
 *
 *   java -cp <generator classpath> RuneRunner <runtime classpath file> <jar with Rune files>...
 *
 * Reads requests from standard input, one per line:
 *   <file.rosetta> TAB <work dir> TAB <pairs file> TAB <input type>
 * and answers each with lines "issue\t<severity>\t<line>\t<message>", then
 * "done\terror", or "done\tok\t<reports written>\t<instructions that failed>\t<report function>".
 *
 * The generator runs on this process's class path; DRR's runtime in a class
 * loader of its own (the runtime classpath file, DRR's), kept between
 * requests so that DRR's classes are loaded once; the generated classes in
 * a child loader per request.
 */
public class RuneRunner {
    public static void main(String[] args) throws Exception {
        long t0 = System.currentTimeMillis();
        Injector inj = new RosettaStandaloneSetup().createInjectorAndDoEMFRegistration();
        XtextResourceSet rs = inj.getInstance(XtextResourceSet.class);
        int n = 0;
        for (int i = 1; i < args.length; i++) {
            try (JarFile jf = new JarFile(args[i])) {
                for (Enumeration<JarEntry> es = jf.entries(); es.hasMoreElements(); ) {
                    JarEntry e = es.nextElement();
                    if (e.getName().endsWith(".rosetta")) {
                        rs.getResource(URI.createURI("jar:" + new File(args[i]).toURI() + "!/" + e.getName()), true);
                        n++;
                    }
                }
            }
        }
        // the runtime: DRR's classpath (relative entries are relative to the file's folder)
        File cpFile = new File(args[0]);
        List<URL> urls = new ArrayList<>();
        StringBuilder javacCp = new StringBuilder();
        for (String e : Files.readString(cpFile.toPath()).trim().split(":")) {
            File f = new File(e).isAbsolute() ? new File(e) : new File(cpFile.getParentFile(), e);
            urls.add(f.toURI().toURL());
            if (javacCp.length() > 0) javacCp.append(File.pathSeparator);
            javacCp.append(f.getAbsolutePath());
        }
        URLClassLoader runtime = new URLClassLoader(urls.toArray(new URL[0]), ClassLoader.getPlatformClassLoader());
        IResourceValidator validator = inj.getInstance(IResourceValidator.class);
        RosettaGenerator gen = inj.getInstance(RosettaGenerator.class);
        JavaCompiler javac = ToolProvider.getSystemJavaCompiler();
        System.out.println("ready\t" + n + " Rune files\t" + (System.currentTimeMillis() - t0) / 1000 + "s");
        System.out.flush();

        Resource previous = null;
        BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
        String line;
        while ((line = in.readLine()) != null) {
            String[] r = line.split("\t");
            if (r.length < 4) { System.out.println("done\terror\tbad request"); System.out.flush(); continue; }
            long t1 = System.currentTimeMillis();
            try {
                if (previous != null) { previous.unload(); rs.getResources().remove(previous); }
                Resource mine = rs.getResource(URI.createFileURI(new File(r[0]).getAbsolutePath()), true);
                previous = mine;
                EcoreUtil.resolveAll(mine);
                boolean errors = false;
                for (Issue i : validator.validate(mine, CheckMode.ALL, CancelIndicator.NullImpl)) {
                    if (i.getMessage().startsWith("Unused import")) continue;
                    System.out.println("issue\t" + i.getSeverity() + "\t" + i.getLineNumber() + "\t" + i.getMessage().replace('\n', ' '));
                    if (i.getSeverity() == org.eclipse.xtext.diagnostics.Severity.ERROR) errors = true;
                }
                if (errors) { System.out.println("done\terror\tvalidation"); System.out.flush(); continue; }
                File work = new File(r[1]), genDir = new File(work, "gen"), classes = new File(work, "classes");
                deleteTree(genDir.toPath()); deleteTree(classes.toPath());
                genDir.mkdirs(); classes.mkdirs();
                JavaIoFileSystemAccess fsa = inj.getInstance(JavaIoFileSystemAccess.class);
                java.util.Map<String, OutputConfiguration> ocs = new java.util.HashMap<>();
                for (String name : new String[] {IFileSystemAccess.DEFAULT_OUTPUT, "src-gen", "DEFAULT_OUTPUT"}) {
                    OutputConfiguration oc = new OutputConfiguration(name);
                    oc.setOutputDirectory(genDir.getAbsolutePath());
                    oc.setOverrideExistingResources(true);
                    oc.setCreateOutputDirectory(true);
                    ocs.put(name, oc);
                }
                fsa.setOutputConfigurations(ocs);
                GeneratorContext ctx = new GeneratorContext();
                ctx.setCancelIndicator(CancelIndicator.NullImpl);
                gen.beforeGenerate(mine, fsa, ctx);
                gen.doGenerate(mine, fsa, ctx);
                gen.afterGenerate(mine, fsa, ctx);
                List<String> sources = new ArrayList<>();
                String fn = null;
                try (Stream<Path> ps = Files.walk(genDir.toPath())) {
                    for (Path p : (Iterable<Path>) ps::iterator) {
                        String s = p.toString();
                        if (s.endsWith(".java")) {
                            sources.add(s);
                            if (s.endsWith("ReportFunction.java"))
                                fn = genDir.toPath().relativize(p).toString().replace(File.separatorChar, '.').replaceAll("\\.java$", "");
                        }
                    }
                }
                List<String> jargs = new ArrayList<>(List.of("-nowarn", "-cp", javacCp.toString(), "-d", classes.getAbsolutePath()));
                jargs.addAll(sources);
                java.io.ByteArrayOutputStream err = new java.io.ByteArrayOutputStream();
                int rc = javac.run(null, null, err, jargs.toArray(new String[0]));
                if (rc != 0) {
                    for (String l : err.toString().split("\n")) if (l.contains("error")) System.out.println("issue\tERROR\t0\t" + l);
                    System.out.println("done\terror\tcompile"); System.out.flush(); continue;
                }
                if (fn == null) { System.out.println("done\terror\tno report function"); System.out.flush(); continue; }
                URLClassLoader mineLoader = new URLClassLoader(new URL[] {classes.toURI().toURL()}, runtime);
                Thread.currentThread().setContextClassLoader(mineLoader);
                Class<?> oracle = Class.forName("DrrOracle", true, mineLoader);
                int[] res = (int[]) oracle.getMethod("runPairs", String.class, String.class, String.class, ClassLoader.class)
                                          .invoke(null, fn, r[3], r[2], mineLoader);
                System.out.println("done\tok\t" + res[0] + "\t" + res[1] + "\t" + fn + "\t" + (System.currentTimeMillis() - t1) / 1000 + "s");
            } catch (Throwable e) {
                Throwable c = e.getCause() != null ? e.getCause() : e;
                System.out.println("done\terror\t" + c.toString().replace('\n', ' '));
            }
            System.out.flush();
        }
        System.exit(0);
    }

    static void deleteTree(Path p) throws Exception {
        if (!Files.exists(p)) return;
        try (Stream<Path> ps = Files.walk(p)) {
            ps.sorted(java.util.Comparator.reverseOrder()).forEach(q -> q.toFile().delete());
        }
    }
}
