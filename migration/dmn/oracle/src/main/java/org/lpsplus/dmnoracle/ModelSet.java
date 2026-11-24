package org.lpsplus.dmnoracle;

import java.io.IOException;
import java.io.StringReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Stream;

import javax.xml.namespace.QName;

import org.drools.kiesession.rulebase.InternalKnowledgeBase;
import org.kie.api.io.Resource;
import org.kie.dmn.api.core.DMNModel;
import org.kie.dmn.api.core.DMNRuntime;
import org.kie.dmn.api.core.event.DMNRuntimeEventListener;
import org.kie.dmn.api.marshalling.DMNMarshaller;
import org.kie.dmn.backend.marshalling.v1x.DMNMarshallerFactory;
import org.kie.dmn.core.compiler.DMNCompilerConfigurationImpl;
import org.kie.dmn.core.compiler.DMNCompilerImpl;
import org.kie.dmn.core.compiler.DMNProfile;
import org.kie.dmn.core.compiler.RuntimeTypeCheckOption;
import org.kie.dmn.core.compiler.profiles.ExtendedDMNProfile;
import org.kie.dmn.core.impl.DMNRuntimeImpl;
import org.kie.dmn.core.impl.DMNRuntimeKB;
import org.kie.dmn.model.api.Definitions;
import org.kie.dmn.model.api.Import;
import org.kie.dmn.core.compiler.DMNImportsUtil;
import org.kie.internal.io.ResourceFactory;

/**
 * Loads DMN files the way the DMN TCK Drools runner does (DMNRuntimeBuilder.usingStrict(): runtime type check on,
 * no extended profile), but file by file, so that one broken file does not stop the others, and with imports
 * resolved by namespace among all the files given.
 *
 * Files that share (namespace, name) with an earlier file are compiled in a later "round", each round with its own
 * DMNRuntime; their imports are resolved against the files of that round first, then against round 0.
 */
public final class ModelSet {

    public static final class Options {
        public boolean normalise = false;
        public boolean typeCheck = true;
        public boolean extendedProfile = false;
    }

    public static final class LoadedFile {
        public final Path path;
        public String text;
        public Definitions defs;
        public final List<String> loadErrors = new ArrayList<>();   // unmarshalling / import / compile exceptions
        public final List<String> normalisations = new ArrayList<>();
        public final List<String> notes = new ArrayList<>();
        public DMNModel model;
        public DMNRuntime runtime;
        public int round;

        LoadedFile(Path path) {
            this.path = path;
        }

        public QName qname() {
            return defs == null ? null : new QName(defs.getNamespace(), defs.getName());
        }
    }

    public final List<LoadedFile> files = new ArrayList<>();
    private final Options options;

    private ModelSet(Options options) {
        this.options = options;
    }

    /** The DMN files under the given files/directories: *.dmn, and *.xml whose root element is a DMN definitions. */
    public static List<Path> collect(List<String> args) throws IOException {
        Set<Path> out = new LinkedHashSet<>();
        for (String a : args) {
            Path p = Path.of(a).toAbsolutePath().normalize();
            if (Files.isDirectory(p)) {
                try (Stream<Path> s = Files.walk(p)) {
                    s.filter(Files::isRegularFile).filter(ModelSet::looksLikeDmn).sorted().forEach(out::add);
                }
            } else if (Files.isRegularFile(p)) {
                out.add(p);
            } else {
                throw new IOException("No such file or directory: " + a);
            }
        }
        return new ArrayList<>(out);
    }

    static boolean looksLikeDmn(Path p) {
        String n = p.getFileName().toString().toLowerCase();
        if (n.endsWith(".dmn")) {
            return true;
        }
        if (!n.endsWith(".xml")) {
            return false;
        }
        try (var in = Files.newInputStream(p)) {
            String head = new String(in.readNBytes(4096), StandardCharsets.UTF_8);
            int i = head.indexOf("definitions");
            return i >= 0 && head.contains("/spec/DMN/") && !head.contains("<testCases");
        } catch (IOException e) {
            return false;
        }
    }

    public static ModelSet load(List<Path> paths, Options options) {
        ModelSet ms = new ModelSet(options);
        ms.doLoad(paths);
        return ms;
    }

    private final List<DMNProfile> profiles = new ArrayList<>();

    private DMNCompilerConfigurationImpl compilerConfig() {
        DMNCompilerConfigurationImpl cc = new DMNCompilerConfigurationImpl();
        cc.setRootClassLoader(null);
        cc.setProperty(new RuntimeTypeCheckOption(options.typeCheck).getPropertyName(), "" + options.typeCheck);
        if (options.extendedProfile) {
            DMNProfile p = new ExtendedDMNProfile();
            profiles.add(p);
            cc.addExtensions(p.getExtensionRegisters());
            cc.addDRGElementCompilers(p.getDRGElementCompilers());
            cc.addFEELProfile(p);
        }
        return cc;
    }

    private void doLoad(List<Path> paths) {
        DMNCompilerConfigurationImpl cc = compilerConfig();
        DMNMarshaller marshaller = cc.getRegisteredExtensions().isEmpty()
                ? DMNMarshallerFactory.newDefaultMarshaller()
                : DMNMarshallerFactory.newMarshallerWithExtensions(cc.getRegisteredExtensions());
        for (Path p : paths) {
            LoadedFile lf = new LoadedFile(p);
            files.add(lf);
            try {
                lf.text = Files.readString(p, StandardCharsets.UTF_8);
            } catch (IOException e) {
                try {
                    lf.text = Files.readString(p, StandardCharsets.ISO_8859_1);
                } catch (IOException e2) {
                    lf.loadErrors.add("cannot read file: " + e2);
                    continue;
                }
            }
            if (options.normalise) {
                lf.text = Normaliser.normalise(lf.text, lf.normalisations);
            }
            try {
                lf.defs = marshaller.unmarshal(new StringReader(lf.text));
                if (lf.defs == null) {
                    lf.loadErrors.add("unmarshalling returned no definitions (not a DMN file, or an unsupported DMN namespace)");
                }
            } catch (Throwable t) {
                lf.loadErrors.add("unmarshalling failed: " + oneLine(t));
            }
        }
        // rounds: the k-th occurrence of a (namespace, name) goes to round k
        Map<QName, Integer> seen = new HashMap<>();
        int rounds = 0;
        for (LoadedFile lf : files) {
            if (lf.defs == null) {
                continue;
            }
            int k = seen.merge(lf.qname(), 1, Integer::sum) - 1;
            lf.round = k;
            if (k > 0) {
                lf.notes.add("another file earlier in the list has the same namespace and name; compiled separately (round " + k + ")");
            }
            rounds = Math.max(rounds, k + 1);
        }
        List<LoadedFile> round0 = new ArrayList<>();
        for (int r = 0; r < rounds; r++) {
            List<LoadedFile> members = new ArrayList<>();
            for (LoadedFile lf : files) {
                if (lf.defs != null && lf.round == r) {
                    members.add(lf);
                }
            }
            compileRound(cc, members, r == 0 ? List.of() : round0);
            if (r == 0) {
                round0 = members;
            }
        }
    }

    /** Compile one round: each member, after the files it imports (topological order). */
    private void compileRound(DMNCompilerConfigurationImpl cc, List<LoadedFile> members, List<LoadedFile> fallback) {
        Map<LoadedFile, List<LoadedFile>> deps = new LinkedHashMap<>();
        Set<LoadedFile> extra = new LinkedHashSet<>();   // files from round 0 that this round's members import
        for (LoadedFile lf : members) {
            deps.put(lf, resolveImports(lf, members, fallback, extra));
        }
        // the imported round-0 files are recompiled in this round too (a DMNModel belongs to one runtime)
        List<LoadedFile> extraCopies = new ArrayList<>();
        for (LoadedFile e : extra) {
            if (!members.contains(e)) {
                extraCopies.add(e);
            }
        }
        for (LoadedFile e : extraCopies) {
            deps.putIfAbsent(e, resolveImports(e, members, fallback, new LinkedHashSet<>()));
        }
        List<LoadedFile> order = new ArrayList<>();
        Set<LoadedFile> visiting = new LinkedHashSet<>();
        Set<LoadedFile> done = new LinkedHashSet<>();
        for (LoadedFile lf : deps.keySet()) {
            visit(lf, deps, visiting, done, order);
        }
        DMNCompilerImpl compiler = new DMNCompilerImpl(cc);
        List<DMNModel> compiled = new ArrayList<>();
        Map<LoadedFile, DMNModel> local = new HashMap<>();
        for (LoadedFile lf : order) {
            try {
                Definitions defs = lf.defs;
                if (extraCopies.contains(lf)) {   // a fresh object tree: the compiler annotates the definitions
                    defs = DMNMarshallerFactory.newDefaultMarshaller().unmarshal(new StringReader(lf.text));
                }
                Resource res = ResourceFactory.newByteArrayResource(lf.text.getBytes(StandardCharsets.UTF_8));
                res.setSourcePath(lf.path.toString());
                DMNModel m = compiler.compile(defs, res, compiled);
                if (m == null) {
                    if (!extraCopies.contains(lf)) {
                        lf.loadErrors.add("the compiler returned no model");
                    }
                } else {
                    compiled.add(m);
                    local.put(lf, m);
                }
            } catch (Throwable t) {
                if (!extraCopies.contains(lf)) {
                    lf.loadErrors.add("compilation threw: " + oneLine(t));
                }
            }
        }
        DMNRuntimeImpl rt = new DMNRuntimeImpl(new StaticKB(compiled, profiles));
        rt.setOption(new RuntimeTypeCheckOption(options.typeCheck));
        for (LoadedFile lf : members) {
            lf.model = local.get(lf);
            lf.runtime = rt;
        }
    }

    private static void visit(LoadedFile lf, Map<LoadedFile, List<LoadedFile>> deps, Set<LoadedFile> visiting,
                              Set<LoadedFile> done, List<LoadedFile> order) {
        if (done.contains(lf)) {
            return;
        }
        if (visiting.contains(lf)) {
            lf.loadErrors.add("circular import involving " + lf.qname());
            return;
        }
        visiting.add(lf);
        for (LoadedFile d : deps.getOrDefault(lf, List.of())) {
            visit(d, deps, visiting, done, order);
        }
        visiting.remove(lf);
        done.add(lf);
        order.add(lf);
    }

    private List<LoadedFile> resolveImports(LoadedFile lf, List<LoadedFile> members, List<LoadedFile> fallback,
                                            Set<LoadedFile> extra) {
        List<LoadedFile> out = new ArrayList<>();
        for (Import i : lf.defs.getImport()) {
            if (DMNImportsUtil.whichImportType(i) != DMNImportsUtil.ImportType.DMN) {
                continue;
            }
            var r = DMNImportsUtil.resolveImportDMN(i, members, LoadedFile::qname);
            if (r.isLeft() && !fallback.isEmpty()) {
                var r2 = DMNImportsUtil.resolveImportDMN(i, fallback, LoadedFile::qname);
                if (r2.isRight()) {
                    LoadedFile d = r2.getOrElse(null);
                    out.add(d);
                    collectTransitive(d, fallback, extra);
                    continue;
                }
            }
            if (r.isLeft()) {
                lf.loadErrors.add("unresolved import '" + i.getName() + "' (namespace " + i.getNamespace() + ", locationURI "
                        + i.getLocationURI() + ") among the files given");
            } else {
                out.add(r.getOrElse(null));
            }
        }
        return out;
    }

    private void collectTransitive(LoadedFile d, List<LoadedFile> fallback, Set<LoadedFile> extra) {
        if (!extra.add(d)) {
            return;
        }
        for (Import i : d.defs.getImport()) {
            var r = DMNImportsUtil.resolveImportDMN(i, fallback, LoadedFile::qname);
            if (r.isRight()) {
                collectTransitive(r.getOrElse(null), fallback, extra);
            }
        }
    }

    /** Find a model by file path (exact, or ending), by namespace + name, or by name alone. */
    public LoadedFile find(String file, String namespace, String name) {
        if (file != null) {
            Path p = Path.of(file).toAbsolutePath().normalize();
            for (LoadedFile lf : files) {
                if (lf.path.equals(p)) {
                    return lf;
                }
            }
            for (LoadedFile lf : files) {
                if (lf.path.toString().endsWith(file)) {
                    return lf;
                }
            }
            return null;
        }
        LoadedFile hit = null;
        for (LoadedFile lf : files) {
            if (lf.defs == null) {
                continue;
            }
            if ((namespace == null || namespace.equals(lf.defs.getNamespace())) && (name == null || name.equals(lf.defs.getName()))) {
                if (hit == null || lf.round < hit.round) {
                    hit = lf;
                }
            }
        }
        return hit;
    }

    static String oneLine(Throwable t) {
        StringBuilder sb = new StringBuilder();
        Throwable c = t;
        int depth = 0;
        while (c != null && depth < 4) {
            if (depth > 0) {
                sb.append(" / caused by ");
            }
            sb.append(c.getClass().getSimpleName()).append(": ").append(String.valueOf(c.getMessage()).replace('\n', ' '));
            c = c.getCause() == c ? null : c.getCause();
            depth++;
        }
        return sb.toString();
    }

    private static final class StaticKB implements DMNRuntimeKB {
        private final List<DMNModel> models;
        private final List<DMNProfile> profiles;

        StaticKB(List<DMNModel> models, List<DMNProfile> profiles) {
            this.models = Collections.unmodifiableList(new ArrayList<>(models));
            this.profiles = List.copyOf(profiles);
        }

        @Override
        public List<DMNModel> getModels() {
            return models;
        }

        @Override
        public DMNModel getModel(String namespace, String modelName) {
            return models.stream().filter(m -> m.getNamespace().equals(namespace) && m.getName().equals(modelName)).findFirst().orElse(null);
        }

        @Override
        public DMNModel getModelById(String namespace, String modelId) {
            return models.stream().filter(m -> m.getNamespace().equals(namespace) && m.getDefinitions().getId().equals(modelId)).findFirst().orElse(null);
        }

        @Override
        public List<DMNProfile> getProfiles() {
            return profiles;
        }

        @Override
        public List<DMNRuntimeEventListener> getListeners() {
            return List.of();
        }

        @Override
        public ClassLoader getRootClassLoader() {
            return null;
        }

        @Override
        public InternalKnowledgeBase getInternalKnowledgeBase() {
            throw new UnsupportedOperationException();
        }
    }
}
