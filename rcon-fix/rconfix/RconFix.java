package rconfix;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.FileSystem;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.tree.AbstractInsnNode;
import org.objectweb.asm.tree.ClassNode;
import org.objectweb.asm.tree.FrameNode;
import org.objectweb.asm.tree.MethodInsnNode;
import org.objectweb.asm.tree.MethodNode;

public final class RconFix {
    private static final String CLIENT_ENTRY = "net/minecraft/server/rcon/thread/RconClient.class";
    private static final String TEMPLATE = "rconfix/RconClientTemplate";
    private static final String SEND_DESC = "(IILjava/lang/String;)V";
    private static final String RESPONSE_DESC = "(ILjava/lang/String;)V";
    private static final String CHUNKS = "rconfix$chunks";

    private RconFix() {
    }

    public static void main(String[] args) throws IOException {
        int patched = 0;
        for (String arg : args) {
            Path jar = Path.of(arg);
            try (FileSystem zip = FileSystems.newFileSystem(jar)) {
                Path entry = zip.getPath(CLIENT_ENTRY);
                if (Files.exists(entry)) {
                    Files.write(entry, patch(Files.readAllBytes(entry)));
                    System.out.println("rcon-fix: patched " + jar);
                    patched++;
                }
            }
        }
        if (patched == 0) {
            throw new IllegalStateException("rcon-fix: no jar contains " + CLIENT_ENTRY);
        }
    }

    static byte[] patch(byte[] clientBytes) throws IOException {
        ClassNode client = read(clientBytes);
        ClassNode template;
        try (InputStream in = RconFix.class.getResourceAsStream("/" + TEMPLATE + ".class")) {
            template = read(in.readAllBytes());
        }

        MethodNode send = only(client, SEND_DESC);
        MethodNode response = only(client, RESPONSE_DESC);
        if (client.methods.stream().anyMatch(m -> m.name.equals(CHUNKS))) {
            throw new IllegalStateException("rcon-fix: " + client.name + " is already patched");
        }

        Map<String, String> names = Map.of("send", send.name, "sendCmdResponse", response.name, CHUNKS, CHUNKS);
        MethodNode newResponse = named(template, "sendCmdResponse");
        MethodNode chunks = named(template, CHUNKS);
        retarget(newResponse, client.name, names);
        retarget(chunks, client.name, names);

        newResponse.name = response.name;
        newResponse.access = response.access;
        newResponse.exceptions = response.exceptions;
        client.methods.set(client.methods.indexOf(response), newResponse);
        client.methods.add(chunks);

        ClassWriter writer = new ClassWriter(ClassWriter.COMPUTE_MAXS);
        client.accept(writer);
        return writer.toByteArray();
    }

    private static ClassNode read(byte[] bytes) {
        ClassNode node = new ClassNode();
        new ClassReader(bytes).accept(node, 0);
        return node;
    }

    private static MethodNode only(ClassNode owner, String desc) {
        List<MethodNode> matches = owner.methods.stream()
            .filter(m -> m.desc.equals(desc) && (m.access & org.objectweb.asm.Opcodes.ACC_STATIC) == 0)
            .toList();
        if (matches.size() != 1) {
            throw new IllegalStateException("rcon-fix: expected one instance method " + desc + " in " + owner.name + ", found " + matches.size());
        }
        return matches.get(0);
    }

    private static MethodNode named(ClassNode owner, String name) {
        return owner.methods.stream()
            .filter(m -> m.name.equals(name))
            .findFirst()
            .orElseThrow(() -> new IllegalStateException("rcon-fix: template is missing " + name));
    }

    private static void retarget(MethodNode method, String clientName, Map<String, String> names) {
        method.localVariables = null;
        for (AbstractInsnNode insn : method.instructions) {
            if (insn instanceof MethodInsnNode call && call.owner.equals(TEMPLATE)) {
                String name = names.get(call.name);
                if (name == null) {
                    throw new IllegalStateException("rcon-fix: template calls unexpected method " + call.name);
                }
                call.owner = clientName;
                call.name = name;
            } else if (insn instanceof FrameNode frame) {
                replace(frame.local, clientName);
                replace(frame.stack, clientName);
            }
        }
        for (AbstractInsnNode insn : method.instructions) {
            String text = insn instanceof MethodInsnNode call ? call.owner + call.desc : "";
            if (text.contains(TEMPLATE)) {
                throw new IllegalStateException("rcon-fix: template reference left in " + method.name);
            }
        }
    }

    private static void replace(List<Object> types, String clientName) {
        if (types == null) {
            return;
        }
        types.replaceAll(type -> TEMPLATE.equals(type) ? clientName : type);
    }
}
