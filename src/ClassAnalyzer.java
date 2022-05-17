
/*
  Jardeps - per-tree Java dependencies in Make
  Copyright (c) 2007-16,2018-19,2021-22, Lancaster University

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;

@Deprecated
class ClassAnalyzer {
    @SuppressWarnings("unused")
    private File srcFile(String className) {
        return new File(srcRoot, className.replace('.', '/') + ".java");
    }

    @SuppressWarnings("unused")
    private File classFile(String className) {
        return new File(classRoot, className.replace('.', '/') + ".class");
    }

    final String tree;
    final File srcRoot;
    final File annSrcRoot;
    final File classRoot;
    final File apiFile;
    final File ppiFile;
    final File listFile;
    final File depsFile;
    final File srcListFile;
    final File usedPackageListFile;
    final File providedPackageListFile;

    final ClassTracker tracker;

    ClassAnalyzer(String tree, File srcRoot, File annSrcRoot, File classRoot,
                  File apiFile, File ppiFile, File listFile, File depsFile,
                  File srcListFile, File usedPackageListFile,
                  File providedPackageListFile,
                  List<? extends ClassId> rootClasses) {
        this.tree = tree;
        this.srcRoot = srcRoot;
        this.annSrcRoot = annSrcRoot;
        this.classRoot = classRoot;
        this.apiFile = apiFile;
        this.ppiFile = ppiFile;
        this.listFile = listFile;
        this.depsFile = depsFile;
        this.srcListFile = srcListFile;
        this.usedPackageListFile = usedPackageListFile;
        this.providedPackageListFile = providedPackageListFile;
        tracker = new ClassTracker(Collections.singletonList(srcRoot),
                                   Collections.singletonList(classRoot),
                                   rootClasses);
    }

    @SuppressWarnings("unused")
    private enum Type {
        BOOLEAN('Z', Boolean.TYPE),
        CHAR('C', Character.TYPE),
        SHORT('S', Short.TYPE),
        INT('I', Integer.TYPE),
        LONG('J', Long.TYPE),
        BYTE('B', Byte.TYPE),
        FLOAT('F', Float.TYPE),
        DOUBLE('D', Double.TYPE);

        Type(char code, Class<?> clazz) {
            this.code = code;
            this.clazz = clazz;
        }

        public final char code;
        public final Class<?> clazz;
    }

    /* This is the set of lines to print out into the public signature
     * file. It includes all public and protected members. */
    final Collection<String> publicMemberLines = new TreeSet<String>();

    /* This is the set of lines to print out into the package-private
     * signature file. It includes all public, protected and
     * package-private members. */
    final Collection<String> packageMemberLines = new TreeSet<String>();

    private class ClassProcess {
        private final ClassId clid;
        private final File file;

        // private Visibility visibility = Visibility.PRIVATE;

        ClassProcess(ClassId clid) {
            this.clid = clid;
            file = clid.binaryFile(classRoot);
        }

        void run() throws Exception {
            DataInputStream in =
                new DataInputStream(new FileInputStream(file));
            try {
                // System.err.println("Processing " + clid);

                /* Check for magic number. */
                int magic = in.readInt();
                if (magic != 0xCAFEBABE) {
                    System.err.println("Not a class: " + file);
                    return;
                }

                /* Read and ignore version numbers. */
                in.readUnsignedShort();
                in.readUnsignedShort();

                /* Read in the constant pool data and resolve
                 * indices. */
                ConstantPool pool = ConstantPool.build(in);

                /* Read class flags. */
                int classFlags = in.readUnsignedShort();
                boolean synthetic =
                    (classFlags & Constants.ACC_SYNTHETIC) != 0;
                Visibility visibility = Visibility.forFlags(classFlags);
                boolean anonymous = clid.isAnonymous();

                /* Ignore class name. TODO: Check it? Use it in
                 * preference? */
                in.readUnsignedShort();

                /* Build an erased signature, to be overwritten by a
                 * generic one if found in the attributes. */
                StringBuilder signature = new StringBuilder();

                /* Identify the superclass. */
                final ClassId superclass =
                    pool.getClass(in.readUnsignedShort());
                signature.append('L').append(superclass).append(';');
                tracker.submit(superclass);

                /* Identify the interfaces. */
                final int interfaceCount = in.readUnsignedShort();
                for (int i = 0; i < interfaceCount; i++) {
                    ClassId ifname = pool.getClass(in.readUnsignedShort());
                    signature.append('L').append(ifname).append(';');
                    tracker.submit(ifname);
                }

                /* Parse the fields. */
                final int fieldCount = in.readUnsignedShort();
                List<MemberEntry> fields =
                    new ArrayList<MemberEntry>(fieldCount);
                for (int i = 0; i < fieldCount; i++)
                    fields.add(MemberEntry.parseField(clid, in, pool));

                /* Parse the methods. */
                final int methodCount = in.readUnsignedShort();
                List<MemberEntry> methods =
                    new ArrayList<MemberEntry>(methodCount);
                for (int i = 0; i < methodCount; i++)
                    methods.add(MemberEntry.parseMethod(clid, in, pool));

                /* Prepare to record nested structure. */
                class InnerInfo {
                    final ClassId outer;
                    final int flags;
                    final Visibility visibility;

                    InnerInfo(ClassId outer, int flags) {
                        this.outer = outer;
                        this.flags = flags;
                        visibility = Visibility.forFlags(flags);
                    }
                }
                Map<ClassId, InnerInfo> inners =
                    new HashMap<ClassId, InnerInfo>();

                /* Process class attributes. */
                final int attrCount = in.readUnsignedShort();
                // boolean deprecated = false;
                for (int i = 0; i < attrCount; i++) {
                    String name = pool.getText(in.readUnsignedShort());
                    int length = in.readInt();
                    if (name.equals("InnerClasses")) {
                        int numPairs = in.readUnsignedShort();
                        for (int j = 0; j < numPairs; j++) {
                            int innerInfo = in.readUnsignedShort();
                            int outerInfo = in.readUnsignedShort();
                            @SuppressWarnings("unused")
                            int innerIndex = in.readUnsignedShort();
                            int innerFlags = in.readUnsignedShort();
                            if (innerInfo != 0 && outerInfo != 0) {
                                ClassId innerId = pool.getClass(innerInfo);
                                ClassId outerId = pool.getClass(outerInfo);
                                InnerInfo info =
                                    new InnerInfo(outerId, innerFlags);
                                inners.put(innerId, info);
                            }
                        }
                    } else if (name.equals("Signature")) {
                        assert length == 2;
                        signature.delete(0, signature.length());
                        signature
                            .append(pool.getText(in.readUnsignedShort()));
                    } else {
                        in.skipBytes(length);
                    }
                }

                /* If we're a nested class, walk through our containers,
                 * tracking visibility, anonymity, syntheticity. */
                for (ClassId curr = clid; curr != null;) {
                    InnerInfo info = inners.get(clid);
                    if (info == null) break;

                    /* Merge concealing attributes. */
                    visibility = visibility.min(info.visibility);
                    if ((info.flags & Constants.ACC_SYNTHETIC) != 0)
                        synthetic = true;
                    if (info.outer.isAnonymous()) anonymous = true;

                    /* Move on to the next. */
                    if (info.outer.equals(curr)) break;
                    curr = info.outer;
                }

                /* Build up the class signature line. */
                StringBuilder classLine = new StringBuilder(160);
                classLine.append(clid);
                if ((classFlags & Constants.ACC_ENUM) != 0)
                    classLine.append(" enums");
                else if ((classFlags & Constants.ACC_ANNOTATION) != 0)
                    classLine.append(" annot");
                else if ((classFlags & Constants.ACC_INTERFACE) != 0)
                    classLine.append(" iface");
                else {
                    classLine.append(" class");
                    if ((classFlags & Constants.ACC_ABSTRACT) != 0)
                        classLine.append(" abstract");
                    if ((classFlags & Constants.ACC_FINAL) != 0)
                        classLine.append(" final");
                }
                switch (visibility) {
                case PUBLIC:
                    classLine.append(" public");
                    break;
                default:
                    break;
                case PROTECTED:
                    classLine.append(" protected");
                    break;
                case PRIVATE:
                    classLine.append(" private");
                    break;
                }

                /* Add the most detailed class signature to the class
                 * line. */
                classLine.append(' ').append(signature);

                /* TODO: Add class annotations. */

                /* Submit the most detailed class signature for
                 * dependency processing. */
                tracker.submitClassSignature(signature.toString());

                /* Process the fields. */
                for (MemberEntry entry : fields) {
                    /* If the containing class or this member is
                     * anonymous, synthetic, or invisible, we don't
                     * bother writing signature lines. */
                    if (anonymous) continue;
                    if (synthetic || entry.isSynthetic()) continue;
                    Visibility computedVisibility =
                        visibility.min(entry.visibility());
                    if (!computedVisibility.isVisible()) continue;

                    /* Generate a signature line for this member. */
                    StringBuilder line = new StringBuilder();
                    line.delete(0, line.length());
                    line.append(clid).append('.');
                    line.append(entry.name());
                    line.append(" field ");
                    switch (entry.visibility()) {
                    case PUBLIC:
                        line.append("public ");
                        break;
                    default:
                        break;
                    case PROTECTED:
                        line.append("protected ");
                        break;
                    case PRIVATE:
                        line.append("private ");
                        break;
                    }
                    if (entry.isStatic()) line.append("static ");
                    if (entry.isFinal()) line.append("final ");
                    if (entry.isVolatile()) line.append("volatile ");
                    if (entry.isTransient()) line.append("transient ");
                    if (entry.isDeprecated()) line.append("deprecated ");
                    line.append(entry.descriptor());
                    line.append(entry.valueString());

                    /* Add annotations. */
                    for (String annot : entry.annotations()) {
                        line.append(' ');
                        line.append(annot);
                    }

                    /* Add the signature line to the package-private
                     * signature. */
                    packageMemberLines.add(line.toString());

                    /* Don't bother with anything more if this member is
                     * not effectively public or protected. */
                    if (!computedVisibility.isPublic()) continue;

                    /* Add the signature line to the public
                     * signature. */
                    publicMemberLines.add(line.toString());
                }

                /* Process the methods. */
                for (MemberEntry entry : methods) {
                    /* Class initializers form no part of signatures. */
                    if (entry.name().equals("<clinit>")) continue;

                    /* If the containing class or this member is
                     * anonymous, synthetic, or invisible, we don't
                     * bother writing signature lines. */
                    if (anonymous) continue;
                    if (synthetic || entry.isSynthetic()) continue;
                    Visibility computedVisibility =
                        visibility.min(entry.visibility());
                    if (!computedVisibility.isVisible()) continue;

                    /* Generate a signature line for this member. */
                    StringBuilder line = new StringBuilder();
                    line.delete(0, line.length());
                    line.append(clid).append('.');
                    line.append(entry.name());
                    line.append(" method ");
                    switch (entry.visibility()) {
                    case PUBLIC:
                        line.append("public ");
                        break;
                    default:
                        break;
                    case PROTECTED:
                        line.append("protected ");
                        break;
                    case PRIVATE:
                        line.append("private ");
                        break;
                    }
                    if (entry.isStatic()) line.append("static ");
                    if (entry.isFinal()) line.append("final ");
                    if (entry.isVolatile()) line.append("volatile ");
                    if (entry.isTransient()) line.append("transient ");
                    if (entry.isDeprecated()) line.append("deprecated ");
                    line.append(entry.descriptor());
                    line.append(entry.valueString());

                    /* Add exceptions. */
                    for (ClassId ex : entry.exceptions()) {
                        line.append(" ^");
                        line.append(ex);
                    }

                    /* Add annotations. */
                    for (String annot : entry.annotations()) {
                        line.append(' ');
                        line.append(annot);
                    }

                    /* Add parameter annotations. */
                    for (Collection<String> list : entry
                        .parameterAnnotations()) {
                        line.append(" +");
                        for (String annot : list) {
                            line.append(' ');
                            line.append(annot);
                        }
                    }

                    /* Add annotation default value. */
                    if (entry.hasAnnotationDefault()) {
                        line.append(" default ");
                        line.append(entry.annotationDefault());
                    }

                    /* Add the signature line to the package-private
                     * signature. */
                    packageMemberLines.add(line.toString());

                    /* Don't bother with anything more if this member is
                     * not effectively public or protected. */
                    if (!computedVisibility.isPublic()) continue;

                    /* Add the signature line to the public
                     * signature. */
                    publicMemberLines.add(line.toString());
                }

                /* Make sure runtime-referenced classes are submitted
                 * for processing. */
                for (ClassId ref : pool.getClasses())
                    tracker.submit(ref);

                /* We don't add synthetic or anonymous classes to
                 * signature files. */
                if (!anonymous && !synthetic && visibility.isVisible()) {
                    /* Add the class line to the package-private
                     * signature. */
                    packageMemberLines.add(classLine.toString());

                    if (visibility.isPublic()) {
                        /* Add the class line to the public
                         * signature. */
                        publicMemberLines.add(classLine.toString());
                    }
                }
            } finally {
                try {
                    in.close();
                } catch (IOException ex) {
                    ex.printStackTrace();
                }
            }
        }
    }

    void run() throws Exception {
        /* Just keep processing until we've no more jobs left. */
        while (tracker.hasNext())
            new ClassProcess(tracker.next()).run();

        writePublicSignature();
        writePackagePrivateSignature();
        writeContents();
        writeImports();
        writeExports();
        writeDependencies();
        writeSourceList();
    }

    private void writePublicSignature() throws IOException {
        PrintWriter out = new PrintWriter(new FileWriter(apiFile));
        for (String line : publicMemberLines)
            out.println(line);
        out.close();
    }

    private void writePackagePrivateSignature() throws IOException {
        PrintWriter out = new PrintWriter(new FileWriter(ppiFile));
        for (String line : packageMemberLines)
            out.println(line);
        out.close();
    }

    private void writeContents() throws IOException {
        /* Write out the list of generated class files. */
        PrintWriter out = new PrintWriter(new FileWriter(listFile));
        for (ClassId clid : tracker.neededClasses())
            out.println(clid.binaryFile(null));
        out.close();
    }

    private void writeImports() throws IOException {
        PrintWriter out =
            new PrintWriter(new FileWriter(this.usedPackageListFile));
        for (String pkg : tracker.importedPackages())
            out.println(pkg);
        out.close();
    }

    private void writeExports() throws IOException {
        PrintWriter out =
            new PrintWriter(new FileWriter(this.providedPackageListFile));
        for (String pkg : tracker.providedPackages())
            out.println(pkg);
        out.close();
    }

    private void writeSourceList() throws IOException {
        PrintWriter out = new PrintWriter(new FileWriter(srcListFile));
        List<File> sourcePath = Collections.singletonList(srcRoot);
        for (ClassId clid : tracker.sourceClasses()) {
            if (clid.findSource(sourcePath) != null)
                out.printf("%s%n", clid.toExternalName());
        }
        out.close();
    }

    private void writeDependencies() throws IOException {
        /* Write out the dependency information. */
        PrintWriter out = new PrintWriter(new FileWriter(depsFile));
        List<File> sourcePath = Collections.singletonList(srcRoot);
        for (ClassId clid : tracker.sourceClasses()) {
            if (clid.findSource(sourcePath) != null)
                out.printf("srclist-%s += %s%n", tree, clid.sourceFile(null));
        }
        out.close();
    }

    public static void main(String[] args) throws Exception {
        int argi = 0;
        String tree = args[argi++];
        File srcRoot = new File(args[argi++]);
        File annSrcRoot = new File(args[argi++]);
        File classRoot = new File(args[argi++]);
        File apiFile = new File(args[argi++]);
        File ppiFile = new File(args[argi++]);
        File listFile = new File(args[argi++]);
        File depsFile = new File(args[argi++]);
        File srcListFile = new File(args[argi++]);
        File usePackageListFile = new File(args[argi++]);
        File providedPackageListFile = new File(args[argi++]);
        List<String> rootClassNames =
            Arrays.asList(args).subList(argi, args.length);
        List<ClassId> rootClasses =
            new ArrayList<ClassId>(rootClassNames.size());
        for (String name : rootClassNames)
            rootClasses.add(ClassId.forName(name));

        new ClassAnalyzer(tree, srcRoot, annSrcRoot, classRoot, apiFile,
                          ppiFile, listFile, depsFile, srcListFile,
                          usePackageListFile, providedPackageListFile,
                          rootClasses).run();
    }
}
