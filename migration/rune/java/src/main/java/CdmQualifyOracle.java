import com.google.inject.Guice;
import com.google.inject.Injector;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.regnosys.drr.DrrRuntimeModuleTesting;
import com.regnosys.rosetta.common.hashing.ReferenceResolverProcessStep;
import com.regnosys.rosetta.common.serialisation.RosettaObjectMapper;
import com.rosetta.model.lib.RosettaModelObjectBuilder;
import drr.regulation.common.TransactionReportInstruction;
import cdm.product.template.EconomicTerms;
import org.isda.cdm.processor.CdmReferenceConfig;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.List;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

/**
 * The oracle of the CDM's product qualification (the design notes rune.md §13,
 * step 5): the CDM's own Java, its Qualify_* functions of
 * cdm.product.qualification, on the economic terms of the trade of each
 * instruction (its originating workflow step's business event's first
 * after-trade), references resolved as DRR resolves them.
 *
 *   java -cp ... CdmQualifyOracle <cdm-java jar>  < instruction files, one per line
 *
 * Prints one line per instruction: "<file>\t<Qualify_A,Qualify_B,...>" (the
 * functions that hold), or "<file>\terror\t<why>".
 */
public class CdmQualifyOracle {
    public static void main(String[] args) throws Exception {
        Injector injector = Guice.createInjector(new DrrRuntimeModuleTesting());
        List<String> names = new ArrayList<>();
        try (JarFile jf = new JarFile(args[0])) {
            for (Enumeration<JarEntry> es = jf.entries(); es.hasMoreElements(); ) {
                String n = es.nextElement().getName();
                if (n.startsWith("cdm/product/qualification/functions/Qualify_") && n.endsWith(".class") && !n.contains("$"))
                    names.add(n.replace('/', '.').replaceAll("\\.class$", ""));
            }
        }
        java.util.Collections.sort(names);
        List<Object> fns = new ArrayList<>(); List<Method> evs = new ArrayList<>(); List<String> short_ = new ArrayList<>();
        for (String n : names) {
            Class<?> c = Class.forName(n);
            try {
                Method m = c.getMethod("evaluate", EconomicTerms.class);
                fns.add(injector.getInstance(c)); evs.add(m); short_.add(c.getSimpleName());
            } catch (NoSuchMethodException e) { /* a function of other inputs */ }
        }
        ReferenceResolverProcessStep resolver = new ReferenceResolverProcessStep(CdmReferenceConfig.get());
        ObjectMapper mapper = RosettaObjectMapper.getNewRosettaObjectMapper();
        BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
        String line;
        while ((line = in.readLine()) != null) {
            try {
                TransactionReportInstruction read = mapper.readValue(new File(line), TransactionReportInstruction.class);
                RosettaModelObjectBuilder b = read.toBuilder();
                resolver.runProcessStep(b.getType(), b);
                TransactionReportInstruction i = (TransactionReportInstruction) b.build();
                EconomicTerms et = i.getOriginatingWorkflowStep().getBusinessEvent().getAfter().get(0).getTrade().getProduct().getEconomicTerms();
                List<String> holds = new ArrayList<>();
                for (int k = 0; k < fns.size(); k++) {
                    Object r = evs.get(k).invoke(fns.get(k), et);
                    if (Boolean.TRUE.equals(r)) holds.add(short_.get(k));
                }
                System.out.println(line + "\t" + String.join(",", holds));
            } catch (Throwable e) {
                Throwable c = e.getCause() != null ? e.getCause() : e;
                System.out.println(line + "\terror\t" + c.toString().replace('\n', ' '));
            }
        }
        System.out.flush();
        System.exit(0);
    }
}
