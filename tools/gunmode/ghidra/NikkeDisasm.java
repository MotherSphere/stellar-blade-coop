// Prints the instructions around each given address (args after output path: ADDR[:before[:after]]). Read-only.
//@category SB
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import java.io.*;
import java.nio.charset.StandardCharsets;

public class NikkeDisasm extends GhidraScript {
    public void run() throws Exception {
        String[] a = getScriptArgs();
        PrintWriter w = new PrintWriter(new OutputStreamWriter(new FileOutputStream(a[0]), StandardCharsets.UTF_8));
        Listing L = currentProgram.getListing();
        for (int i = 1; i < a.length; i++) {
            String[] p = a[i].split(":");
            int before = p.length > 1 ? Integer.parseInt(p[1]) : 30, after = p.length > 2 ? Integer.parseInt(p[2]) : 30;
            Address ad = toAddr(p[0]);
            w.println("\n##### around " + ad);
            Instruction ins = L.getInstructionContaining(ad);
            if (ins == null) { w.println("no instruction"); continue; }
            Instruction s = ins;
            for (int k = 0; k < before && s.getPrevious() != null; k++) s = s.getPrevious();
            for (int k = 0; k < before + after + 1 && s != null; k++, s = s.getNext()) {
                StringBuilder ex = new StringBuilder();
                for (int o = 0; o < s.getNumOperands(); o++) {
                    for (Object obj : s.getOpObjects(o)) {
                        if (obj instanceof Address) {
                            Data d = L.getDataAt((Address) obj);
                            if (d != null && d.hasStringValue()) ex.append(" ; \"").append(d.getValue()).append("\"");
                            else if (d != null && d.getValue() != null) ex.append(" ; =").append(d.getValue());
                        }
                    }
                }
                w.println((s.getAddress().equals(ins.getAddress()) ? ">> " : "   ") + s.getAddress() + "  " + s + ex);
            }
            w.flush();
        }
        w.println("\nDONE"); w.close();
    }
}
