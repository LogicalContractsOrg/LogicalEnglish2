// DRR's own Java, run as the oracle of the Rune door (../README.md).
//
//   java -cp <classpath> DrrOracle <function class> <input type>
//
// reads lines "<input.json>\t<output.json>" on standard input and writes, for
// each, the report DRR's function computes from that input (an empty object
// "{}" when the function returns nothing), in the same JSON form as the
// expected reports of DRR's test packs.  The clock is DRR's testing one
// (DrrRuntimeModuleTesting: the reporting timestamp of the test packs).
import com.google.inject.Guice;
import com.google.inject.Injector;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.regnosys.drr.DrrRuntimeModuleTesting;
import com.regnosys.rosetta.common.hashing.ReferenceResolverProcessStep;
import org.isda.cdm.processor.CdmReferenceConfig;
import com.rosetta.model.lib.RosettaModelObjectBuilder;
import com.regnosys.rosetta.common.serialisation.RosettaObjectMapper;
import com.rosetta.model.lib.RosettaModelObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.lang.reflect.Method;

public class DrrOracle {
    /**
     * For RuneRunner (java_back): the report function FnClass, loaded by the
     * given class loader, on each line "instruction\treport" of the pairs file.
     * Returns {ok, errors}.
     */
    public static int[] runPairs(String fnClassName, String inTypeName, String pairsFile, ClassLoader cl) throws Exception {
        Class<?> fnClass = Class.forName(fnClassName, true, cl);
        Class<?> inType = Class.forName(inTypeName, true, cl);
        Injector injector = Guice.createInjector(new DrrRuntimeModuleTesting());
        Object fn = injector.getInstance(fnClass);
        Method evaluate = fnClass.getMethod("evaluate", inType);
        ReferenceResolverProcessStep resolver = new ReferenceResolverProcessStep(CdmReferenceConfig.get());
        ObjectMapper mapper = RosettaObjectMapper.getNewRosettaObjectMapper();
        int ok = 0, errors = 0;
        for (String line : java.nio.file.Files.readAllLines(new File(pairsFile).toPath())) {
            String[] io = line.split("\t");
            File out = new File(io[1]);
            out.getParentFile().mkdirs();
            try {
                RosettaModelObject read = (RosettaModelObject) mapper.readValue(new File(io[0]), inType);
                RosettaModelObjectBuilder b = read.toBuilder();
                resolver.runProcessStep(b.getType(), b);
                Object result = evaluate.invoke(fn, b.build());
                Object value = result == null ? mapper.createObjectNode() : result;
                if (result instanceof RosettaModelObject r) value = r.build();
                mapper.writerWithDefaultPrettyPrinter().writeValue(out, value);
                ok++;
            } catch (Throwable e) {
                errors++;
            }
        }
        return new int[] {ok, errors};
    }

    public static void main(String[] args) throws Exception {
        Class<?> fnClass = Class.forName(args[0]);
        Class<?> inType = Class.forName(args[1]);
        Injector injector = Guice.createInjector(new DrrRuntimeModuleTesting());
        Object fn = injector.getInstance(fnClass);
        Method evaluate = fnClass.getMethod("evaluate", inType);
        ReferenceResolverProcessStep resolver = new ReferenceResolverProcessStep(CdmReferenceConfig.get());
        ObjectMapper mapper = RosettaObjectMapper.getNewRosettaObjectMapper();
        BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
        String line;
        while ((line = in.readLine()) != null) {
            String[] io = line.split("\t");
            File out = new File(io[1]);
            out.getParentFile().mkdirs();
            try {
                // As DRR's own test harness does: the references of the
                // input (partyReference -> globalReference) resolved first.
                RosettaModelObject read = (RosettaModelObject) mapper.readValue(new File(io[0]), inType);
                RosettaModelObjectBuilder b = read.toBuilder();
                resolver.runProcessStep(b.getType(), b);
                Object input = b.build();
                Object result = evaluate.invoke(fn, input);
                Object value = result == null ? mapper.createObjectNode() : result;
                if (result instanceof RosettaModelObject r) value = r.build();
                mapper.writerWithDefaultPrettyPrinter().writeValue(out, value);
                System.out.println("ok\t" + io[0]);
            } catch (Throwable e) {
                Throwable c = e.getCause() != null ? e.getCause() : e;
                System.out.println("error\t" + io[0] + "\t" + c);
            }
        }
        System.out.flush();
        System.exit(0);     // DRR's runtime leaves threads (an HTTP client's) that keep the JVM alive
    }
}
