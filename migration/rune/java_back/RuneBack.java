import com.google.inject.Injector;
import com.regnosys.rosetta.RosettaStandaloneSetup;
import com.regnosys.rosetta.generator.RosettaGenerator;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.util.EcoreUtil;
import org.eclipse.xtext.generator.GeneratorContext;
import org.eclipse.xtext.generator.JavaIoFileSystemAccess;
import org.eclipse.xtext.generator.OutputConfiguration;
import org.eclipse.xtext.generator.IFileSystemAccess;
import org.eclipse.xtext.resource.XtextResourceSet;
import org.eclipse.xtext.util.CancelIndicator;
import org.eclipse.xtext.validation.CheckMode;
import org.eclipse.xtext.validation.IResourceValidator;
import org.eclipse.xtext.validation.Issue;

import java.io.File;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.List;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

/**
 * The way back (the design notes rune.md §8 step 6): Rune files written from
 * Logical English, read with the Rune of DRR 7.14.0 and the CDM 6.29 it
 * builds on, checked by Rune's own validator, and turned into Java by Rune's
 * own generator — the Java that DRR's build would make of them.
 *
 *   java -cp ... RuneBack <output directory> <jar with Rune files>... -- <new .rosetta file>...
 *
 * Every Rune file of the jars is loaded (DRR, the CDM, ISO 20022, FpML, Rune's
 * built-in types); only the new files are generated. Prints the validator's
 * issues of the new files; exits 1 when one is an error.
 */
public class RuneBack {
    public static void main(String[] args) throws Exception {
        String out = args[0];
        List<String> jars = new ArrayList<>(), news = new ArrayList<>();
        boolean after = false;
        for (int i = 1; i < args.length; i++) {
            if (args[i].equals("--")) after = true;
            else (after ? news : jars).add(args[i]);
        }
        long t0 = System.currentTimeMillis();
        Injector inj = new RosettaStandaloneSetup().createInjectorAndDoEMFRegistration();
        XtextResourceSet rs = inj.getInstance(XtextResourceSet.class);
        int n = 0;
        for (String j : jars) {
            try (JarFile jf = new JarFile(j)) {
                for (Enumeration<JarEntry> es = jf.entries(); es.hasMoreElements(); ) {
                    JarEntry e = es.nextElement();
                    if (e.getName().endsWith(".rosetta")) {
                        rs.getResource(URI.createURI("jar:" + new File(j).toURI() + "!/" + e.getName()), true);
                        n++;
                    }
                }
            }
        }
        List<Resource> mine = new ArrayList<>();
        for (String f : news) mine.add(rs.getResource(URI.createFileURI(new File(f).getAbsolutePath()), true));
        System.out.println("loaded " + n + " Rune files and " + mine.size() + " new, " + (System.currentTimeMillis() - t0) / 1000 + "s");
        // only the new files are resolved: the others are linked as the new ones need them
        for (Resource r : mine) EcoreUtil.resolveAll(r);
        System.out.println("resolved, " + (System.currentTimeMillis() - t0) / 1000 + "s");

        IResourceValidator v = inj.getInstance(IResourceValidator.class);
        boolean errors = false;
        for (Resource r : mine) {
            for (Issue i : v.validate(r, CheckMode.ALL, CancelIndicator.NullImpl)) {
                System.out.println(i.getSeverity() + " " + r.getURI().lastSegment() + ":" + i.getLineNumber() + ": " + i.getMessage());
                if (i.getSeverity() == org.eclipse.xtext.diagnostics.Severity.ERROR) errors = true;
            }
        }
        if (errors) System.exit(1);

        RosettaGenerator gen = inj.getInstance(RosettaGenerator.class);
        JavaIoFileSystemAccess fsa = inj.getInstance(JavaIoFileSystemAccess.class);
        java.util.Map<String, OutputConfiguration> ocs = new java.util.HashMap<>();
        for (String name : new String[] {IFileSystemAccess.DEFAULT_OUTPUT, "src-gen", "DEFAULT_OUTPUT"}) {
            OutputConfiguration oc = new OutputConfiguration(name);
            oc.setOutputDirectory(out);
            oc.setOverrideExistingResources(true);
            oc.setCreateOutputDirectory(true);
            ocs.put(name, oc);
        }
        fsa.setOutputConfigurations(ocs);
        GeneratorContext ctx = new GeneratorContext();
        ctx.setCancelIndicator(CancelIndicator.NullImpl);
        for (Resource r : mine) {
            gen.beforeGenerate(r, fsa, ctx);
            gen.doGenerate(r, fsa, ctx);
            gen.afterGenerate(r, fsa, ctx);
        }
        System.out.println("generated into " + out + ", " + (System.currentTimeMillis() - t0) / 1000 + "s");
    }
}
