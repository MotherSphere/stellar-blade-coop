// For each UFunction name given: find its ASCII name, the native-function table entry that points at it
// ({const char* name, FNativeFuncPtr exec} pairs), and decompile the exec thunk, the function it forwards to
// (the _Implementation) and that function's callees, to a depth. Read-only.
//@category SB
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class NikkeNative extends GhidraScript {
    PrintWriter w;
    DecompInterface dec;
    Set<Function> done = new HashSet<>();
    int budget = 40;

    void decomp(Function f, int depth, String why) throws Exception {
        if (f == null || done.contains(f) || budget <= 0) return;
        done.add(f); budget--;
        w.println("\n##### " + f.getName() + " @" + f.getEntryPoint() + " size " + f.getBody().getNumAddresses() + "  (" + why + ", depth " + depth + ")");
        StringBuilder callees = new StringBuilder();
        Set<Function> called = f.getCalledFunctions(monitor);
        for (Function c : called) callees.append(c.getName()).append("@").append(c.getEntryPoint()).append(" ");
        w.println("calls: " + callees);
        DecompileResults r = dec.decompileFunction(f, 180, monitor);
        if (r != null && r.getDecompiledFunction() != null) {
            String c = r.getDecompiledFunction().getC();
            w.println(c.length() > 40000 ? c.substring(0, 40000) + "\n... (cut)" : c);
        } else w.println("(decompile failed)");
        w.flush();
        if (depth <= 0) return;
        for (Function c : called) if (c.getBody().getNumAddresses() > 40) decomp(c, depth - 1, "callee of " + f.getName());
    }

    public void run() throws Exception {
        String[] a = getScriptArgs();
        w = new PrintWriter(new OutputStreamWriter(new FileOutputStream(a[0]), StandardCharsets.UTF_8));
        dec = new DecompInterface();
        dec.openProgram(currentProgram);
        Memory mem = currentProgram.getMemory();
        int depth = Integer.parseInt(a[1]);
        for (int i = 2; i < a.length; i++) {
            String name = a[i];
            budget = 40;
            w.println("\n================ " + name);
            if (name.startsWith("@")) {   // @ADDR = decompile this function and its callees directly
                Address ad = toAddr(name.substring(1));
                // the vtable slot is the real entry point: if the project folded it into a neighbour, remove that
                // neighbour and define a function exactly here (read-only project - discarded afterwards)
                Function f = getFunctionAt(ad);
                if (f == null) {
                    Function c = getFunctionContaining(ad);
                    if (c != null) { w.println("removing mis-bounded " + c.getName() + " @" + c.getEntryPoint()); removeFunction(c); }
                    try { clearListing(ad, ad.add(0x40)); } catch (Exception e) {}
                    try { disassemble(ad); } catch (Exception e) {}
                    try { f = createFunction(ad, "NGM_" + name.substring(1)); } catch (Exception e) { w.println("create failed " + e); }
                }
                if (f == null) w.println("no function at " + name); else decomp(f, depth, "given");
                continue;
            }
            byte[] pat = (name + "\0").getBytes(StandardCharsets.US_ASCII);
            Address start = mem.getMinAddress();
            int hits = 0;
            while (start != null && hits < 10 && !monitor.isCancelled()) {
                Address hit = mem.findBytes(start, pat, null, true, monitor);
                if (hit == null) break;
                hits++;
                // must be the whole name (previous byte is 0 or non-identifier)
                byte prev = 0;
                try { prev = mem.getByte(hit.subtract(1)); } catch (Exception e) {}
                start = hit.add(1);
                if (Character.isLetterOrDigit(prev) || prev == '_') continue;
                w.println("ascii at " + hit);
                // scan memory for 8-byte pointers to the string (refs may not be analysed)
                long v = hit.getOffset();
                byte[] ptr = new byte[8];
                for (int k = 0; k < 8; k++) ptr[k] = (byte) (v >> (8 * k));
                Address s2 = mem.getMinAddress();
                int ph = 0;
                while (s2 != null && ph < 6 && !monitor.isCancelled()) {
                    Address p = mem.findBytes(s2, ptr, null, true, monitor);
                    if (p == null) break;
                    ph++;
                    s2 = p.add(1);
                    long exec = mem.getLong(p.add(8));
                    Address ea = toAddr(exec);
                    Function ef = getFunctionAt(ea);
                    if (ef == null) ef = getFunctionContaining(ea);
                    w.println("  pointer at " + p + " -> next qword " + Long.toHexString(exec) + (ef != null ? " = " + ef.getName() : " (no function)"));
                    if (ef != null) decomp(ef, depth, "exec thunk of " + name);
                }
            }
        }
        dec.dispose();
        w.println("\nDONE");
        w.close();
    }
}
