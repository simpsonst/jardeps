package uk.ac.lancs.scc.jardeps.function;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.tools.JavaFileManager;

/**
 * Dynamically defines function types. An example function type looks
 * like this:
 * 
 * <pre>
 * interface Function_VIL<T2> {
 *   void apply(int a1, T2 a2);
 * }
 * </pre>
 * 
 * <p>
 * The type name begins with <samp>Function_</samp>, and continues with
 * a sequence of characters in the set <samp>ZBCSIJFDL</samp>. The first
 * character identifies the return type (<code>boolean</code>,
 * <code>byte</code>, <code>char</code>, <code>short</code>,
 * <code>int</code>, <code>long</code>, <code>float</code>,
 * <code>double</code>, <samp>L</samp> for all reference types, and
 * additionally <samp>V</samp> for <code>void</code>), and each
 * subsequent character indicates the presence and type of a parameter.
 * If a parameter is designated by <samp>L</samp>, its type is a generic
 * type parameter <code>T<var>n</var></code>, where <var>n</var> is the
 * parameter number (starting from 1). If the return type is designated
 * by <samp>L</samp>, the generic type parameter is <code>TR</code>.
 * 
 * <p>
 * Exceptions are not permitted (yet). If the <throws E> generic syntax
 * had been supported, it would have used that, and that would cover all
 * cases, including no exceptions at all.
 * 
 * <p>
 * The intention is that a future Java language would support function
 * types natively, e.g., <code>#int(int, int)</code>, and such a type
 * expression would be mapped to Function_III. Function types would form
 * an infinite set, whose members could be generated on demand.
 * 
 * <p>
 * Providing this classloader is only one of several steps to supporting
 * function types. Obviously, the language has to change to support the
 * compact syntax. Also, a specialized classloader is of no use to a
 * compiler or IDE, which expect to find finite numbers of classes in
 * jars, and don't load them with {@link ClassLoader}. Options include:
 * 
 * <ul>
 * 
 * <li>Encode the understanding of underlying function types into the
 * tool. <kbd>java</kbd> would just 'know' that types like
 * <code>Function_LII</code> exist, and so not report errors on them.
 *
 * <li>Provide frameworks in those tools to allow the new types to be
 * plugged in. <kbd>javac</kbd> could accept a switch to insert a
 * {@link JavaFileManager} into the compilation process, or a bytecode
 * generator abstraction could be injected:
 * 
 * <pre>
 * interface ClassWriter {
 *   byte[] writeClass(String name);
 *   boolean canWriteClass(String name);
 * }
 * 
 * class WrittenClassLoader extends ClassLoader {
 *   WrittenClassLoader(ClassWriter writer, ClassLoader parent);
 * }
 * </pre>
 * 
 * <pre>
 * javac -cw org.example.FunctionClassWriter
 * </pre>
 * 
 * <li>Jar files could be augmented with executable elements that
 * provide the notional content of the jar dynamically.
 * 
 * </ul>
 * 
 * <p>
 * This class is just for toying with the idea, to explore its
 * feasibility, and detect potential problems.
 * 
 * @author simpsons
 */
public final class FunctionTypeClassLoader extends ClassLoader {
    /**
     * @summary The package containing function types, namely
     * <samp>{@value}</samp>
     */
    public static final String packageName = "javax.function";

    private static final Pattern functionPattern =
        Pattern.compile("^" + Pattern.quote(packageName)
            + "\\.Function_([VZBCSIJFDL][ZBCSIJFDL]*)$");

    /**
     * Create a classloader for function types, using a given parent.
     * 
     * @param parent the parent classloader
     */
    public FunctionTypeClassLoader(ClassLoader parent) {
        super(parent);
    }

    @Override
    protected Class<?> findClass(String name) throws ClassNotFoundException {
        /* Determine whether the requested class is one of ours. */
        byte[] buf = getBytes(name);
        if (buf == null) return null;
        return defineClass(name, buf, 0, buf.length);
    }

    /**
     * @undocumented
     * 
     * @param args the name of the class to be created, followed by an
     * optional directory name for writing the output (default: current
     * directory)
     * 
     * @throws Exception
     */
    public static void main(String[] args) throws Exception {
        String name = args[0];
        File dir = args.length < 2 ? null : new File(args[1]);
        if (!dir.exists()) throw new FileNotFoundException(dir.toString());
        File file = new File(dir, name.replace('.', '/') + ".class");
        file.getParentFile().mkdirs();
        byte[] buf = getBytes(name);
        if (buf != null)
            try (FileOutputStream out = new FileOutputStream(file)) {
                out.write(buf);
            }
        ClassLoader loader = new FunctionTypeClassLoader(null);
        Class.forName(name, false, loader);
    }

    /**
     * Get the bytecode for a generic function type.
     * 
     * @param name the name of the requested type
     * 
     * @return the bytecode of the requested type, or {@code null} if
     * not recognized as a function type
     */
    public static byte[] getBytes(String name) {
        Matcher m = functionPattern.matcher(name);
        if (!m.matches()) return null;
        final String params = m.group(1).substring(1);
        final char returnType = m.group(1).charAt(0);

        final String methodName = "apply";
        final String className = name.replace('.', '/');
        final String classSignature = "java/lang/Object";

        final boolean genericArgs;
        final String genericClassSignature;
        {
            StringBuilder buf = new StringBuilder();
            buf.append('<');
            if (returnType == 'L') buf.append("TR:Ljava/lang/Object;");
            for (int i = 0; i < params.length(); i++) {
                char c = params.charAt(i);
                if (c != 'L') continue;
                buf.append('T').append(i + 1);
                buf.append(":Ljava/lang/Object;");
            }

            if (buf.length() > 1) {
                buf.append('>');
                buf.append("Ljava/lang/Object;");
                genericClassSignature = buf.toString();
                genericArgs = true;
            } else {
                genericClassSignature = null;
                genericArgs = false;
            }
        }

        final String genericMethodSignature;
        if (genericArgs) {
            StringBuilder buf = new StringBuilder();
            buf.append('(');
            for (int i = 0; i < params.length(); i++) {
                char c = params.charAt(i);
                if (c == 'L')
                    buf.append("TT").append(i + 1).append(';');
                else
                    buf.append(c);
            }
            buf.append(')');
            if (returnType == 'L')
                buf.append("TTR;");
            else
                buf.append(returnType);
            genericMethodSignature = buf.toString();
        } else {
            genericMethodSignature = null;
        }

        final String methodSignature;
        {
            StringBuilder buf = new StringBuilder();
            buf.append('(');
            for (int i = 0; i < params.length(); i++) {
                char c = params.charAt(i);
                if (c == 'L')
                    buf.append("Ljava/lang/Object;");
                else
                    buf.append(c);
            }
            buf.append(')');
            if (returnType == 'L')
                buf.append("Ljava/lang/Object;");
            else
                buf.append(returnType);
            methodSignature = buf.toString();
        }

        /* We need three extra entries in the pool for generic signature
         * stuff. */
        final int poolSize = 7 + (genericArgs ? 3 : 0);

        try (ByteArrayOutputStream arrayStr = new ByteArrayOutputStream();
            DataOutputStream out = new DataOutputStream(arrayStr)) {
            out.writeInt(0xcafebabe); // magic
            out.writeShort(0); // minor version
            out.writeShort(50); // major version
            out.writeShort(poolSize); // 1+pool size

            int nextIndex = 1;
            final int genSigLabelIdx, genMethSigIdx, genClsSigIdx;
            // Write pool entries.
            if (genericArgs) {
                out.writeByte(1); // Utf8
                out.writeUTF("Signature");
                genSigLabelIdx = nextIndex++;

                out.writeByte(1); // Utf8
                out.writeUTF(genericMethodSignature);
                genMethSigIdx = nextIndex++;

                out.writeByte(1); // Utf8
                out.writeUTF(genericClassSignature);
                genClsSigIdx = nextIndex++;
            } else {
                genSigLabelIdx = genMethSigIdx = genClsSigIdx = 0;
            }

            out.writeByte(1); // Utf8
            out.writeUTF(methodName);
            final int methNameIdx = nextIndex++;

            out.writeByte(1); // Utf8
            out.writeUTF(methodSignature);
            final int methSigIdx = nextIndex++;

            out.writeByte(1); // Utf8
            out.writeUTF(className);
            final int clsNameIdx = nextIndex++;

            out.writeByte(1); // Utf8
            out.writeUTF(classSignature);
            final int clsSigIdx = nextIndex++;

            out.writeByte(7); // Class
            out.writeShort(clsNameIdx);
            final int clsNameClsIdx = nextIndex++;

            out.writeByte(7); // Class
            out.writeShort(clsSigIdx);
            final int clsSigClsIdx = nextIndex++;

            // Access flags, PUBLIC | INTERFACE | ABSTRACT
            out.writeShort(0x601);

            // Our name
            out.writeShort(clsNameClsIdx);

            // Supertype name
            out.writeShort(clsSigClsIdx);

            // Number of interfaces implemented
            out.writeShort(0);

            // Number of fields
            out.writeShort(0);

            // Number of methods
            out.writeShort(1);

            // Write one method.
            out.writeShort(0x401); // PUBLIC | ABSTRACT
            out.writeShort(methNameIdx);
            out.writeShort(methSigIdx);
            if (genericArgs) {
                out.writeShort(1); // 1 method attribute
                out.writeShort(genSigLabelIdx);
                out.writeInt(2); // size; pool reference
                out.writeShort(genMethSigIdx);
            } else {
                out.writeShort(0); // no method attributes
            }

            if (genericArgs) {
                out.writeShort(1); // 1 class attribute
                out.writeShort(genSigLabelIdx);
                out.writeInt(2); // size; pool reference
                out.writeShort(genClsSigIdx);
            } else {
                out.writeShort(0); // no class attributes
            }
            out.flush();
            return arrayStr.toByteArray();
        } catch (IOException ex) {
            throw new AssertionError("unreachable", ex);
        }
    }
}
