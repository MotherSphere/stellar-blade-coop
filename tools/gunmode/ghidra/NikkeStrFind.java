// Lists defined strings containing any of the given substrings (args after the output path), with the
// functions that reference them. Read-only.
//@category SB
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class NikkeStrFind extends GhidraScript {
    public void run() throws Exception {
        String[] a = getScriptArgs();
        PrintWriter w = new PrintWriter(new OutputStreamWriter(new FileOutputStream(a[0]), StandardCharsets.UTF_8));
        int hits = 0;
        DataIterator it = currentProgram.getListing().getDefinedData(true);
        while (it.hasNext() && !monitor.isCancelled()) {
            Data d = it.next();
            if (!d.hasStringValue()) continue;
            Object v = d.getValue();
            if (v == null) continue;
            String s = v.toString();
            boolean m = false;
            for (int i = 1; i < a.length; i++) if (s.contains(a[i])) { m = true; break; }
            if (!m) continue;
            if (++hits > 400) break;
            StringBuilder sb = new StringBuilder();
            int n = 0;
            for (Reference r : getReferencesTo(d.getAddress())) {
                Function f = getFunctionContaining(r.getFromAddress());
                sb.append(r.getFromAddress()).append(f != null ? "(" + f.getName() + ")" : "").append(" ");
                if (++n > 12) { sb.append("..."); break; }
            }
            w.println(d.getAddress() + "  \"" + s + "\"  refs: " + sb);
            w.flush();
        }
        w.println("hits " + hits + "\nDONE");
        w.close();
    }
}
