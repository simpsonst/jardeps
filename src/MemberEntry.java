
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
import java.util.Collections;
import java.util.List;
import java.util.TreeSet;

class MemberEntry {
    static String readElement(DataInput in, ConstantPool pool)
        throws IOException {
        char c = (char) in.readUnsignedByte();
        switch (c) {
        case 'B':
        case 'C':
        case 'D':
        case 'F':
        case 'I':
        case 'J':
        case 'S':
        case 'Z': {
            Object value = pool.getConstant(in.readUnsignedShort());
            return valueString(value);
        }

        case 'c': {
            String value = pool.getText(in.readUnsignedShort());
            return value;
        }

        case 's':
            return valueString(pool.getText(in.readUnsignedShort()));

        case 'e': {
            String typeName = pool.getText(in.readUnsignedShort());
            String valueName = pool.getText(in.readUnsignedShort());
            return typeName + '.' + valueName;
        }

        case '@': {
            return readAnnotation(in, pool);
        }

        case '[': {
            StringBuilder result = new StringBuilder();
            result.append('[');
            int numVals = in.readUnsignedShort();
            for (int i = 0; i < numVals; i++) {
                if (i > 0) result.append(',');
                result.append(readElement(in, pool));
            }
            result.append(']');
            return result.toString();
        }

        default:
            throw new IllegalArgumentException("Annotation value "
                + "not recognized: " + c);
        }
    }

    static String readAnnotation(DataInput in, ConstantPool pool)
        throws IOException {
        String type = pool.getText(in.readUnsignedShort());
        final int numPairs = in.readUnsignedShort();
        List<String> values = new ArrayList<>();
        for (int k = 0; k < numPairs; k++) {
            String name = pool.getText(in.readUnsignedShort());
            values.add(name + '=' + readElement(in, pool));
        }
        Collections.sort(values);

        StringBuilder repr = new StringBuilder();
        repr.append('@').append(type).append('(');
        String sep = "";
        for (String v : values) {
            repr.append(sep);
            sep = ",";
            repr.append(v);
        }
        repr.append(')');
        return repr.toString();
    }

    static String readTypeAnnotation(DataInput in, ConstantPool pool)
        throws IOException {
        StringBuilder prefix = new StringBuilder();
        boolean skip = false;

        /* Work out what the annotation actually applies to. */
        int targetType = in.readUnsignedByte();
        switch (targetType) {
        case 0x00:
        case 0x01:
            prefix.append("tvar[").append(in.readUnsignedByte()).append("]");
            break;

        case 0x10:
            prefix.append("super[").append(in.readUnsignedShort())
                .append("]");
            break;

        case 0x11:
        case 0x12:
            prefix.append("tvar[").append(in.readUnsignedByte()).append('.')
                .append(in.readUnsignedByte()).append("]");
            break;

        case 0x13:
        case 0x14:
        case 0x15:
            prefix.append("result");
            break;

        case 0x16:
            prefix.append("fparam[").append(in.readUnsignedByte())
                .append("]");
            break;

        case 0x17:
            prefix.append("throws[").append(in.readUnsignedShort())
                .append("]");
            break;

        case 0x40:
        case 0x41:
            skip = true;
            in.skipBytes(6 * in.readUnsignedShort());
            break;

        case 0x42:
        case 0x43:
        case 0x44:
        case 0x45:
        case 0x46:
            skip = true;
            in.skipBytes(2);
            break;

        case 0x47:
        case 0x48:
        case 0x49:
        case 0x4a:
        case 0x4b:
            skip = true;
            in.skipBytes(3);
            break;

        default:
            System.err.println("Warning: unknown annotation target type "
                + targetType);
            break;
        }

        /* Read the target path. */
        int numElems = in.readUnsignedByte();
        for (int i = 0; i < numElems; i++) {
            prefix.append('/').append(in.readUnsignedByte());
            prefix.append('[').append(in.readUnsignedByte()).append(']');
        }

        if (skip) {
            readAnnotation(in, pool);
            return null;
        }

        /* Append the annotation details. */
        return prefix + readAnnotation(in, pool);
    }

    MemberEntry(boolean isMethod, ClassId container, DataInput in,
                ConstantPool pool)
        throws IOException {
        this.isMethod = isMethod;
        this.container = container;
        flags = in.readUnsignedShort();
        name = pool.getText(in.readUnsignedShort());
        /* This pulls in the runtime (erased) signature. */
        rawDescriptor = descriptor = pool.getText(in.readUnsignedShort());
        final int attrCount = in.readUnsignedShort();
        for (int i = 0; i < attrCount; i++) {
            String name = pool.getText(in.readUnsignedShort());
            int length = in.readInt();
            if (name.equals("ConstantValue")) {
                assert length == 2;
                hasValue = true;
                value = pool.getConstant(in.readUnsignedShort());
            } else if (name.equals("Synthetic")) {
                assert length == 0;
                synthetic = true;
            } else if (name.equals("Signature")) {
                assert length == 2;
                /* This pulls in the generic signature. */
                descriptor = pool.getText(in.readUnsignedShort());
            } else if (name.equals("Exceptions")) {
                final int exCount = in.readUnsignedShort();
                for (int j = 0; j < exCount; j++) {
                    ClassId clid = pool.getClass(in.readUnsignedShort());
                    exceptions.add(clid);
                }
            } else if (name.equals("Deprecated")) {
                assert length == 0;
                deprecated = true;
            } else if (name.equals("RuntimeVisibleAnnotations")
                || name.equals("RuntimeInvisibleAnnotations")) {
                final int numAnnots = in.readUnsignedShort();
                for (int j = 0; j < numAnnots; j++)
                    annotations.add(readAnnotation(in, pool));
            } else if (name.equals("RuntimeVisibleParameterAnnotations")
                || name.equals("RuntimeInvisibleParameterAnnotations")) {
                final int numParams = in.readUnsignedByte();
                for (int k = 0; k < numParams; k++) {
                    final int numAnnots = in.readUnsignedShort();
                    List<String> list = new ArrayList<String>(numAnnots);
                    paramAnnotations.add(list);
                    for (int j = 0; j < numAnnots; j++)
                        list.add(readAnnotation(in, pool));
                }
            } else if (name.equals("RuntimeVisibleTypeAnnotations")
                || name.equals("RuntimeInvisibleTypeAnnotations")) {
                final int numAnnots = in.readUnsignedShort();
                for (int j = 0; j < numAnnots; j++)
                    annotations.add(readTypeAnnotation(in, pool));
            } else if (name.equals("AnnotationDefault")) {
                hasDefault = true;
                annotDefault = readElement(in, pool);
            } else {
                in.skipBytes(length);
            }
        }
    }

    private final List<String> annotations = new ArrayList<String>();
    private final List<List<String>> paramAnnotations =
        new ArrayList<List<String>>();

    public Collection<String> annotations() {
        return Collections.unmodifiableCollection(annotations);
    }

    public List<Collection<String>> parameterAnnotations() {
        List<Collection<String>> result = new ArrayList<Collection<String>>();
        for (List<String> item : paramAnnotations)
            result.add(Collections.unmodifiableCollection(item));
        return Collections.unmodifiableList(result);
    }

    public static MemberEntry parseField(ClassId container, DataInput in,
                                         ConstantPool pool)
        throws IOException {
        return new MemberEntry(false, container, in, pool);
    }

    public static MemberEntry parseMethod(ClassId container, DataInput in,
                                          ConstantPool pool)
        throws IOException {
        return new MemberEntry(true, container, in, pool);
    }

    public boolean isPublic() {
        return (flags & Constants.ACC_PUBLIC) != 0;
    }

    public boolean isProtected() {
        return (flags & Constants.ACC_PROTECTED) != 0;
    }

    public boolean isPrivate() {
        return (flags & Constants.ACC_PRIVATE) != 0;
    }

    public boolean isStatic() {
        return (flags & Constants.ACC_STATIC) != 0;
    }

    public boolean isVolatile() {
        return (flags & Constants.ACC_VOLATILE) != 0;
    }

    public boolean isFinal() {
        return (flags & Constants.ACC_FINAL) != 0;
    }

    public boolean isTransient() {
        return (flags & Constants.ACC_TRANSIENT) != 0;
    }

    public boolean isBridge() {
        return (flags & Constants.ACC_BRIDGE) != 0;
    }

    public boolean isVarargs() {
        return (flags & Constants.ACC_VARARGS) != 0;
    }

    public boolean isSynthetic() {
        return (flags & Constants.ACC_SYNTHETIC) != 0;
    }

    public String name() {
        return name;
    }

    public String descriptor() {
        return descriptor;
    }

    public String rawDescriptor() {
        return rawDescriptor;
    }

    public int flags() {
        return flags;
    }

    public Visibility visibility() {
        return Visibility.forFlags(flags);
    }

    public boolean isDeprecated() {
        return deprecated;
    }

    public boolean hasValue() {
        return hasValue;
    }

    public Object value() {
        return value;
    }

    private static String valueString(Object value) {
        if (value instanceof String) {
            String altered = value.toString();
            altered = altered.replaceAll("\\\\", "\\\\");
            altered = altered.replaceAll("\n", "\\n");
            altered = altered.replaceAll("\t", "\\t");
            altered = altered.replaceAll("\r", "\\r");
            altered = altered.replaceAll("\b", "\\b");
            altered = altered.replaceAll("\"", "\\\"");
            return "\"" + altered + "\"";
        }
        if (value instanceof ClassId) { return "L" + value + ";"; }
        return "" + value;
    }

    public String valueString() {
        if (!hasValue) return "";
        return "=" + valueString(value);
    }

    public boolean synthetic() {
        return synthetic || (flags & Constants.ACC_SYNTHETIC) != 0;
    }

    public boolean hasAnnotationDefault() {
        return hasDefault;
    }

    public String annotationDefault() {
        return annotDefault;
    }

    public Collection<ClassId> exceptions() {
        return Collections.unmodifiableCollection(exceptions);
    }

    public ClassId getContainer() {
        return container;
    }

    public boolean isMethod() {
        return isMethod;
    }

    private final ClassId container;
    private final boolean isMethod;
    private boolean deprecated;
    private boolean synthetic;
    private boolean hasValue, hasDefault;
    private Object value;
    private int flags;
    private String name, rawDescriptor, descriptor, annotDefault;
    private final Collection<ClassId> exceptions = new TreeSet<ClassId>();
}
