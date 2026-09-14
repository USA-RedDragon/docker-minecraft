package rconfix;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

final class RconClientTemplate {
    private static final int MAX_BODY_BYTES = 4086;

    private void send(int id, int type, String message) throws IOException {
    }

    private void sendCmdResponse(int id, String response) throws IOException {
        for (String chunk : rconfix$chunks(response)) {
            this.send(id, 0, chunk);
        }
    }

    private static String[] rconfix$chunks(String response) {
        List<String> chunks = new ArrayList<>();
        int start = 0;
        int bytes = 0;
        for (int i = 0; i < response.length(); ) {
            int codePoint = response.codePointAt(i);
            int width = codePoint < 0x80 ? 1 : codePoint < 0x800 ? 2 : codePoint < 0x10000 ? 3 : 4;
            if (bytes + width > MAX_BODY_BYTES) {
                chunks.add(response.substring(start, i));
                start = i;
                bytes = 0;
            }
            bytes += width;
            i += Character.charCount(codePoint);
        }
        chunks.add(response.substring(start));
        return chunks.toArray(new String[0]);
    }
}
