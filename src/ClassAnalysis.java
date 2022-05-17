
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

import java.io.DataInput;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Represents a parsed classfile.
 * 
 * @author simpsons
 */
public final class ClassAnalysis {
    public static class InnerInfo {
        final ClassId outer;
        final int flags;
        final Visibility visibility;

        InnerInfo(ClassId outer, int flags) {
            this.outer = outer;
            this.flags = flags;
            visibility = Visibility.forFlags(flags);
        }
    }

    private ClassId clid;
    private int majorVersion, minorVersion;
    private ConstantPool constantPool;
    private int classFlags;
    private boolean synthetic;
    private boolean anonymous;
    private Visibility visibility;
    private String signature;
    private ClassId superclass;
    private List<String> annotations;
    private List<ClassId> interfaces;
    private List<MemberEntry> fields;
    private List<MemberEntry> methods;
    private Map<ClassId, InnerInfo> inners;

    /**
     * Clear all data.
     */
    public void clear() {
        clid = null;
        majorVersion = minorVersion = 0;
        constantPool = null;
        classFlags = 0;
        synthetic = anonymous = false;
        visibility = null;
        signature = null;
        superclass = null;
        interfaces = null;
        fields = null;
        methods = null;
        inners = null;
        annotations = null;
    }

    /**
     * Get all the classes referred to be this class in its constant
     * constantPool.
     * 
     * @param into the destination for all class references
     */
    public void getRuntimeClassReferences(Collection<? super ClassId> into) {
        for (ClassId ref : constantPool.getClasses()) {
            ref = ref.baseType();
            if (ref == null) continue;
            into.add(ref);
        }
    }

    /**
     * Get the generic signature of this class. If no generic signature
     * is provided, the raw signature will be returned, since they are
     * identical.
     */
    public String getSignature() {
        return signature;
    }

    /**
     * Get the id of the class currently described by this object.
     */
    public ClassId getClassId() {
        return clid;
    }

    /**
     * Get the major version number of the classfile format represented
     * the currently described class.
     */
    public int getMajorVersion() {
        return majorVersion;
    }

    /**
     * Get the minor version number of the classfile format represented
     * the currently described class.
     */
    public int getMinorVersion() {
        return minorVersion;
    }

    /**
     * Get a line contributing to the profile of this class.
     */
    public String getProfileClassLine() {
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

        /* Add the most detailed class signature to the class line. */
        classLine.append(' ').append(signature);

        /* Add class annotations. */
        for (String annot : annotations)
            if (annot != null) classLine.append(' ').append(annot);

        return classLine.toString();
    }

    /**
     * Create the public and package-private profiles of this class.
     * 
     * @param publicMemberLines the public profile to be added to
     * 
     * @param packageMemberLines the package-private profile to be added
     * to
     */
    public void
        createProfiles(Collection<? super String> publicMemberLines,
                       Collection<? super String> packageMemberLines) {
        final String classLine = getProfileClassLine();
        /* We don't add synthetic or anonymous classes to signature
         * files. */
        if (!anonymous && !synthetic && visibility.isVisible()) {
            /* Add the class line to the package-private signature. */
            packageMemberLines.add(classLine.toString());

            if (visibility.isPublic()) {
                /* Add the class line to the public signature. */
                publicMemberLines.add(classLine.toString());
            }
        }

        /* Process the fields. */
        for (MemberEntry entry : fields) {
            /* If the containing class or this member is anonymous,
             * synthetic, or invisible, we don't bother writing
             * signature lines. */
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

            /* Add annotations. TODO: Sort them? */
            for (String annot : entry.annotations())
                if (annot != null) line.append(' ').append(annot);

            /* Add the signature line to the package-private
             * signature. */
            packageMemberLines.add(line.toString());

            /* Don't bother with anything more if this member is not
             * effectively public or protected. */
            if (!computedVisibility.isPublic()) continue;

            /* Add the signature line to the public signature. */
            publicMemberLines.add(line.toString());
        }

        /* Process the methods. */
        for (MemberEntry entry : methods) {
            /* Class initializers form no part of signatures. */
            if (entry.name().equals("<clinit>")) continue;

            /* If the containing class or this member is anonymous,
             * synthetic, or invisible, we don't bother writing
             * signature lines. */
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

            /* Add annotations. TODO: Sort them. */
            for (String annot : entry.annotations())
                if (annot != null) line.append(' ').append(annot);

            /* Add parameter annotations. */
            for (Collection<String> list : entry.parameterAnnotations()) {
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

            /* Don't bother with anything more if this member is not
             * effectively public or protected. */
            if (!computedVisibility.isPublic()) continue;

            /* Add the signature line to the public signature. */
            publicMemberLines.add(line.toString());
        }
    }

    /**
     * Load a class from a file.
     * 
     * @param clid the id of the class expected in the file, or null to
     * disable checking
     * 
     * @param in the raw classfile data
     */
    public void load(ClassId clid, DataInput in) throws IOException {
        clear();

        try {
            /* Check for magic number. */
            int magic = in.readInt();
            if (magic != 0xCAFEBABE)
                throw new IllegalArgumentException("Not a class");

            /* Read and ignore version numbers. */
            majorVersion = in.readUnsignedShort();
            minorVersion = in.readUnsignedShort();

            /* Read in the constant constantPool data and resolve
             * indices. */
            constantPool = ConstantPool.build(in);

            /* Read class flags. */
            classFlags = in.readUnsignedShort();
            synthetic = (classFlags & Constants.ACC_SYNTHETIC) != 0;
            visibility = Visibility.forFlags(classFlags);
            anonymous = clid.isAnonymous();

            /* Get the class name, and optionally check it against what
             * is expected. */
            int nameIndex = in.readUnsignedShort();
            this.clid = constantPool.getClass(nameIndex);
            if (clid != null && !clid.equals(this.clid))
                throw new IllegalArgumentException("Class mismatch,"
                    + " expected " + clid + "; found " + this.clid);

            annotations = new ArrayList<>();

            /* Build an erased signature, to be overwritten by a generic
             * one if found in the attributes. */
            StringBuilder signature = new StringBuilder();

            /* Identify the superclass. */
            superclass = constantPool.getClass(in.readUnsignedShort());
            signature.append('L').append(superclass).append(';');

            /* Identify the interfaces. */
            final int interfaceCount = in.readUnsignedShort();
            interfaces = new ArrayList<>(interfaceCount);
            for (int i = 0; i < interfaceCount; i++) {
                ClassId ifid = constantPool.getClass(in.readUnsignedShort());
                signature.append('L').append(ifid).append(';');
                interfaces.add(ifid);
            }

            /* Parse the fields. */
            final int fieldCount = in.readUnsignedShort();
            fields = new ArrayList<MemberEntry>(fieldCount);
            for (int i = 0; i < fieldCount; i++)
                fields.add(MemberEntry.parseField(clid, in, constantPool));

            /* Parse the methods. */
            final int methodCount = in.readUnsignedShort();
            methods = new ArrayList<MemberEntry>(methodCount);
            for (int i = 0; i < methodCount; i++)
                methods.add(MemberEntry.parseMethod(clid, in, constantPool));

            /* Prepare to record nested structure. */
            inners = new HashMap<ClassId, InnerInfo>();

            /* Process class attributes. */
            final int attrCount = in.readUnsignedShort();
            for (int i = 0; i < attrCount; i++) {
                String name = constantPool.getText(in.readUnsignedShort());
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
                            ClassId innerId =
                                constantPool.getClass(innerInfo);
                            ClassId outerId =
                                constantPool.getClass(outerInfo);
                            InnerInfo info =
                                new InnerInfo(outerId, innerFlags);
                            inners.put(innerId, info);
                        }
                    }
                } else if (name.equals("Signature")) {
                    assert length == 2;
                    signature.delete(0, signature.length());
                    signature
                        .append(constantPool.getText(in.readUnsignedShort()));
                } else if (name.equals("RuntimeVisibleAnnotations")
                    || name.equals("RuntimeInvisibleAnnotations")) {
                    final int numAnnots = in.readUnsignedShort();
                    for (int j = 0; j < numAnnots; j++)
                        annotations.add(MemberEntry
                            .readAnnotation(in, constantPool));
                } else if (name.equals("RuntimeVisibleTypeAnnotations")
                    || name.equals("RuntimeInvisibleTypeAnnotations")) {
                    final int numAnnots = in.readUnsignedShort();
                    for (int j = 0; j < numAnnots; j++)
                        annotations.add(MemberEntry
                            .readTypeAnnotation(in, constantPool));
                } else {
                    in.skipBytes(length);
                }
            }

            /* TODO: Sort class annotations? */

            /* Record the generic signature. */
            this.signature = signature.toString();

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

        } catch (Throwable t) {
            clear();
            throw t;
        }
    }
}
