// Decompiles the functions at the given addresses (script args after the output path), plus the
// functions that call them and the functions they call (one level, named list only). Read-only.
//@category SB
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class NikkeDecomp extends GhidraScript {
    public void run() throws Exception {
        String[] a = getScriptArgs();
        PrintWriter w = new PrintWriter(new OutputStreamWriter(new FileOutputStream(a[0]), StandardCharsets.UTF_8));
        DecompInterface dec = new DecompInterface();
        dec.openProgram(currentProgram);
        List<String> todo = new ArrayList<>();
        for (int i = 1; i < a.length; i++) {
            if (a[i].startsWith("x:")) {   // x:ADDR = the functions that read/write this data address
                Address d = toAddr(a[i].substring(2));
                w.println("\n##### refs to " + d);
                int n = 0;
                Set<Function> seen = new LinkedHashSet<>();
                for (Reference r : getReferencesTo(d)) {
                    Function f = getFunctionContaining(r.getFromAddress());
                    w.println("  " + r.getReferenceType() + " from " + r.getFromAddress() + (f != null ? " in " + f.getName() : ""));
                    if (f != null && seen.add(f) && n++ < 6) todo.add(f.getEntryPoint().toString());
                }
            } else todo.add(a[i]);
        }
        for (String s : todo) {
            Address ad = toAddr(s);
            Function f = getFunctionAt(ad);
            if (f == null) f = getFunctionContaining(ad);
            if (f == null) { w.println("\n##### no function at " + s); continue; }
            w.println("\n##### " + f.getName() + " @" + f.getEntryPoint() + "  size " + f.getBody().getNumAddresses());
            StringBuilder callers = new StringBuilder();
            for (Function c : f.getCallingFunctions(monitor)) callers.append(c.getName()).append("@").append(c.getEntryPoint()).append(" ");
            w.println("callers: " + callers);
            StringBuilder callees = new StringBuilder();
            for (Function c : f.getCalledFunctions(monitor)) callees.append(c.getName()).append("@").append(c.getEntryPoint()).append(" ");
            w.println("calls: " + callees);
            try {
                DecompileResults r = dec.decompileFunction(f, 180, monitor);
                if (r != null && r.getDecompiledFunction() != null) {
                    String c = r.getDecompiledFunction().getC();
                    w.println(c.length() > 60000 ? c.substring(0, 60000) + "\n... (cut)" : c);
                } else w.println("(decompile failed: " + (r == null ? "null" : r.getErrorMessage()) + ")");
            } catch (Exception ex) { w.println("(decompile error " + ex + ")"); }
            w.flush();
        }
        dec.dispose();
        w.println("\nDONE");
        w.close();
    }
}
