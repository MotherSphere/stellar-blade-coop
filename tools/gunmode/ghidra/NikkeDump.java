// Dumps everything in the Stellar Blade Ghidra project that touches the NIKKE gun mode:
// named functions, strings and the functions that use them (decompiled). Read-only.
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

public class NikkeDump extends GhidraScript {
    PrintWriter w;
    LinkedHashMap<Function, String> funcs = new LinkedHashMap<>();

    void addFunc(Function f, String why) {
        if (f == null) return;
        if (!funcs.containsKey(f)) funcs.put(f, why);
        else if (funcs.get(f).length() < 400) funcs.put(f, funcs.get(f) + " | " + why);
    }

    void refsTo(Address a, String why) {
        for (Reference r : getReferencesTo(a)) {
            Function f = getFunctionContaining(r.getFromAddress());
            w.println("    ref from " + r.getFromAddress() + (f != null ? " in " + f.getName() + " @" + f.getEntryPoint() : " (no function)"));
            addFunc(f, why);
        }
    }

    void searchBytes(String s) throws Exception {
        Memory mem = currentProgram.getMemory();
        byte[][] pats = { s.getBytes(StandardCharsets.US_ASCII), s.getBytes(StandardCharsets.UTF_16LE) };
        String[] kind = { "ascii", "utf16" };
        for (int k = 0; k < 2; k++) {
            Address start = mem.getMinAddress();
            int n = 0;
            while (start != null && n < 40 && !monitor.isCancelled()) {
                Address hit = mem.findBytes(start, pats[k], null, true, monitor);
                if (hit == null) break;
                n++;
                w.println("  [" + kind[k] + "] \"" + s + "\" at " + hit);
                refsTo(hit, "str " + s);
                start = hit.add(1);
            }
        }
    }

    public void run() throws Exception {
        String[] args = getScriptArgs();
        String out = args.length > 0 ? args[0] : "nikke_dump.txt";
        w = new PrintWriter(new OutputStreamWriter(new FileOutputStream(out), StandardCharsets.UTF_8));
        w.println("program " + currentProgram.getName() + "  image base " + currentProgram.getImageBase());

        w.println("\n=== 1. functions whose name mentions nikke / tps / minigame / cover ===");
        for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
            String n = f.getName().toLowerCase();
            if (n.contains("nikke") || n.contains("tps") || n.contains("minigame") || n.contains("cover")) {
                w.println("  " + f.getName() + " @" + f.getEntryPoint());
                addFunc(f, "name");
            }
        }

        w.println("\n=== 2. defined strings mentioning nikke / tps ===");
        int ns = 0;
        DataIterator it = currentProgram.getListing().getDefinedData(true);
        while (it.hasNext() && !monitor.isCancelled()) {
            Data d = it.next();
            if (!d.hasStringValue()) continue;
            Object v = d.getValue();
            if (v == null) continue;
            String s = v.toString();
            String l = s.toLowerCase();
            if (s.length() > 200 || !(l.contains("nikke") || l.contains("tps"))) continue;
            if (++ns > 600) break;
            w.println("  \"" + s + "\" @" + d.getAddress());
            refsTo(d.getAddress(), "str " + s);
        }

        w.println("\n=== 3. raw byte search for key names ===");
        String[] keys = { "TPSNikke_Reload", "TPSNikke_CoverPosition", "TPSNikke_ClipInfinity", "TPSNikke",
                          "EffectAction_TPSNikke", "ESBTPSModeType_Nikke", "Eve_NikkeGun", "Bullet_Nikke",
                          "NikkeStage", "HUDTPSNikkeMode", "TPSModeType", "bTPSMode", "IsTPSMode" };
        for (String k : keys) searchBytes(k);

        w.println("\n=== 4. decompiled functions (" + funcs.size() + " found, first 80) ===");
        DecompInterface dec = new DecompInterface();
        dec.openProgram(currentProgram);
        int i = 0;
        for (Map.Entry<Function, String> e : funcs.entrySet()) {
            if (++i > 80 || monitor.isCancelled()) break;
            Function f = e.getKey();
            w.println("\n----- " + f.getName() + " @" + f.getEntryPoint() + "   why: " + e.getValue());
            try {
                DecompileResults r = dec.decompileFunction(f, 90, monitor);
                if (r != null && r.getDecompiledFunction() != null) {
                    String c = r.getDecompiledFunction().getC();
                    w.println(c.length() > 20000 ? c.substring(0, 20000) + "\n... (cut)" : c);
                } else w.println("  (decompile failed)");
            } catch (Exception ex) { w.println("  (decompile error " + ex + ")"); }
            w.flush();
        }
        dec.dispose();
        w.println("\nDONE");
        w.close();
    }
}
