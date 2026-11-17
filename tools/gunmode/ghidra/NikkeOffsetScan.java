// Finds instructions that use a struct offset (script args: out path, then hex offsets like 0x159c) and
// decompiles the functions containing them (first 10). Read-only. (NikkeGunMode 11-16: the NIKKE reticle
// screen point, SBCharacter::NikkeTPSPinScreenPoint @0x159C, to find where it is clamped.)
//@category SB
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.scalar.Scalar;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class NikkeOffsetScan extends GhidraScript {
    public void run() throws Exception {
        String[] a = getScriptArgs();
        PrintWriter w = new PrintWriter(new OutputStreamWriter(new FileOutputStream(a[0]), StandardCharsets.UTF_8));
        Set<Long> offs = new HashSet<>();
        for (int i = 1; i < a.length; i++) offs.add(Long.decode(a[i]));
        Map<Function, List<String>> hits = new LinkedHashMap<>();
        InstructionIterator it = currentProgram.getListing().getInstructions(true);
        long n = 0;
        while (it.hasNext() && !monitor.isCancelled()) {
            Instruction ins = it.next();
            n++;
            for (int op = 0; op < ins.getNumOperands(); op++) {
                for (Object o : ins.getOpObjects(op)) {
                    if (o instanceof Scalar && offs.contains(((Scalar) o).getUnsignedValue())) {
                        Function f = getFunctionContaining(ins.getAddress());
                        if (f == null) continue;
                        hits.computeIfAbsent(f, k -> new ArrayList<>()).add(ins.getAddress() + "  " + ins);
                    }
                }
            }
        }
        w.println("instructions scanned: " + n + ", functions using the offsets: " + hits.size());
        for (Map.Entry<Function, List<String>> e : hits.entrySet()) {
            w.println("  " + e.getKey().getName() + " @" + e.getKey().getEntryPoint() + " size " + e.getKey().getBody().getNumAddresses());
            for (String s : e.getValue()) w.println("      " + s);
        }
        DecompInterface dec = new DecompInterface();
        dec.openProgram(currentProgram);
        int k = 0;
        for (Function f : hits.keySet()) {
            if (k++ >= 10) break;
            w.println("\n##### " + f.getName() + " @" + f.getEntryPoint());
            try {
                DecompileResults r = dec.decompileFunction(f, 180, monitor);
                if (r != null && r.getDecompiledFunction() != null) {
                    String c = r.getDecompiledFunction().getC();
                    w.println(c.length() > 40000 ? c.substring(0, 40000) + "\n... (cut)" : c);
                } else w.println("(decompile failed)");
            } catch (Exception ex) { w.println("(decompile error " + ex + ")"); }
            w.flush();
        }
        dec.dispose();
        w.println("\nDONE");
        w.close();
    }
}
