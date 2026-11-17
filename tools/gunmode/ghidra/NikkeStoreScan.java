// Finds instructions that WRITE to [reg + offset] for the given struct offsets (script args: out path, hex offsets) and
// decompiles each containing function. Read-only. (NikkeGunMode 11-16: who writes SBCharacter::NikkeTPSPinScreenPoint
// @0x159C - the NIKKE reticle position - and clamps it.)
//@category SB
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.lang.OperandType;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class NikkeStoreScan extends GhidraScript {
    public void run() throws Exception {
        String[] a = getScriptArgs();
        PrintWriter w = new PrintWriter(new OutputStreamWriter(new FileOutputStream(a[0]), StandardCharsets.UTF_8));
        w.println("program: " + currentProgram.getName() + " md5 " + currentProgram.getExecutableMD5() + " functions " + currentProgram.getFunctionManager().getFunctionCount());
        Set<Long> offs = new HashSet<>();
        for (int i = 1; i < a.length; i++) offs.add(Long.decode(a[i]));
        Map<Function, List<String>> hits = new LinkedHashMap<>();
        InstructionIterator it = currentProgram.getListing().getInstructions(true);
        while (it.hasNext() && !monitor.isCancelled()) {
            Instruction ins = it.next();
            if (ins.getNumOperands() < 2) continue;
            // destination operand 0 must be a memory reference [reg + disp]
            int t = ins.getOperandType(0);
            if ((t & OperandType.DYNAMIC) == 0) continue;
            String mn = ins.getMnemonicString().toUpperCase();
            if (!(mn.startsWith("MOV") || mn.startsWith("VMOV"))) continue;
            for (Object o : ins.getOpObjects(0)) {
                if (o instanceof Scalar && offs.contains(((Scalar) o).getUnsignedValue())) {
                    Function f = getFunctionContaining(ins.getAddress());
                    if (f != null) hits.computeIfAbsent(f, k -> new ArrayList<>()).add(ins.getAddress() + "  " + ins);
                }
            }
        }
        w.println("functions writing the offsets: " + hits.size());
        for (Map.Entry<Function, List<String>> e : hits.entrySet()) {
            w.println("  " + e.getKey().getName() + " @" + e.getKey().getEntryPoint() + " size " + e.getKey().getBody().getNumAddresses());
            for (String s : e.getValue()) w.println("      " + s);
        }
        DecompInterface dec = new DecompInterface();
        dec.openProgram(currentProgram);
        int k = 0;
        for (Function f : hits.keySet()) {
            if (k++ >= 12) break;
            w.println("\n##### " + f.getName() + " @" + f.getEntryPoint());
            try {
                DecompileResults r = dec.decompileFunction(f, 240, monitor);
                String c = (r != null && r.getDecompiledFunction() != null) ? r.getDecompiledFunction().getC() : "(decompile failed)";
                w.println(c.length() > 30000 ? c.substring(0, 30000) + "\n... (cut)" : c);
            } catch (Exception ex) { w.println("(decompile error " + ex + ")"); }
            w.flush();
        }
        dec.dispose();
        w.println("\nDONE");
        w.close();
    }
}
