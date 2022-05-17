
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
import java.util.HashMap;
import java.util.Map;

class ConstantPoolBuilder {
    private static final int CONSTANT_Class = 7;
    private static final int CONSTANT_Fieldref = 9;
    private static final int CONSTANT_Methodref = 10;
    private static final int CONSTANT_InterfaceMethodref = 11;
    private static final int CONSTANT_String = 8;
    private static final int CONSTANT_Integer = 3;
    private static final int CONSTANT_Float = 4;
    private static final int CONSTANT_Long = 5;
    private static final int CONSTANT_Double = 6;
    private static final int CONSTANT_NameAndType = 12;
    private static final int CONSTANT_Utf8 = 1;
    private static final int CONSTANT_InvokeDynamic = 18;
    private static final int CONSTANT_MethodType = 16;
    private static final int CONSTANT_MethodHandle = 15;

    @SuppressWarnings("unused")
    private static final int REF_getField = 1;
    @SuppressWarnings("unused")
    private static final int REF_getStatic = 2;
    @SuppressWarnings("unused")
    private static final int REF_putField = 3;
    @SuppressWarnings("unused")
    private static final int REF_putStatic = 4;
    @SuppressWarnings("unused")
    private static final int REF_invokeVirtual = 5;
    @SuppressWarnings("unused")
    private static final int REF_invokeStatic = 6;
    @SuppressWarnings("unused")
    private static final int REF_invokeSpecial = 7;
    @SuppressWarnings("unused")
    private static final int REF_newInvokeSpecial = 8;
    @SuppressWarnings("unused")
    private static final int REF_invokeInterface = 9;

    ConstantPool read(DataInput in) throws IOException {
        /* Read in raw pool data. */
        int poolCount = in.readUnsignedShort();
        for (int i = 1; i < poolCount;)
            i += readItem(i, in);

        /* Resolve pool references. */

        Map<Integer, String> strings = new HashMap<Integer, String>();
        for (Map.Entry<Integer, Integer> entry : stringIndices.entrySet()) {
            int index = entry.getKey();
            String value = texts.get(entry.getValue());
            strings.put(index, value);
            constants.put(index, value);
        }

        Map<Integer, ClassId> classes = new HashMap<Integer, ClassId>();
        for (Map.Entry<Integer, Integer> entry : classIndices.entrySet()) {
            int index = entry.getKey();
            ClassId value = ClassId.forName(texts.get(entry.getValue()));
            classes.put(entry.getKey(), value);
            constants.put(index, value);
        }

        Map<Integer, NameAndType> nats = new HashMap<Integer, NameAndType>();
        for (Map.Entry<Integer, NameAndTypeIndex> entry : nameAndTypeIndices
            .entrySet())
            nats.put(entry.getKey(), entry.getValue().resolve());

        Map<Integer, Ref> fieldrefs = new HashMap<Integer, Ref>();
        for (Map.Entry<Integer, RefIndex> entry : fieldrefIndices.entrySet())
            fieldrefs.put(entry.getKey(),
                          entry.getValue().resolve(classes, nats));

        Map<Integer, Ref> methodrefs = new HashMap<Integer, Ref>();
        for (Map.Entry<Integer, RefIndex> entry : methodrefIndices.entrySet())
            methodrefs.put(entry.getKey(),
                           entry.getValue().resolve(classes, nats));

        Map<Integer, Ref> interfaceMethodrefs = new HashMap<Integer, Ref>();
        for (Map.Entry<Integer, RefIndex> entry : interfaceMethodrefIndices
            .entrySet())
            interfaceMethodrefs.put(entry.getKey(),
                                    entry.getValue().resolve(classes, nats));

        /* Build the read-only pool. */
        return new ConstantPool(constants, nats, texts, strings, classes,
                                fieldrefs, methodrefs, interfaceMethodrefs);
    }

    private int readItem(int id, DataInput in) throws IOException {
        int tag = in.readUnsignedByte();
        switch (tag) {
        case CONSTANT_Class: {
            int value = in.readUnsignedShort();
            classIndices.put(id, value);
            // System.err.println("read #" + id + " = Class[#" + value +
            // "]");
            return 1;
        }

        case CONSTANT_Fieldref: {
            int clazzIndex = in.readUnsignedShort();
            int natIndex = in.readUnsignedShort();
            RefIndex value = new RefIndex(clazzIndex, natIndex);
            fieldrefIndices.put(id, value);
            // System.err.println("read #" + id +
            // " = Fieldref[#" + value + "]");
            return 1;
        }

        case CONSTANT_Methodref: {
            int clazzIndex = in.readUnsignedShort();
            int natIndex = in.readUnsignedShort();
            RefIndex value = new RefIndex(clazzIndex, natIndex);
            methodrefIndices.put(id, value);
            // System.err.println("read #" + id +
            // " = Methodref[#" + value + "]");
            return 1;
        }

        case CONSTANT_InterfaceMethodref: {
            int clazzIndex = in.readUnsignedShort();
            int natIndex = in.readUnsignedShort();
            RefIndex value = new RefIndex(clazzIndex, natIndex);
            interfaceMethodrefIndices.put(id, value);
            // System.err.println("read #" + id +
            // " = InterfaceMethodref[#" + value + "]");
            return 1;
        }

        case CONSTANT_String: {
            int value = in.readUnsignedShort();
            stringIndices.put(id, value);
            // System.err.println("read #" + id + " = String[#" + value
            // + "]");
            return 1;
        }

        case CONSTANT_Integer: {
            int value = in.readInt();
            constants.put(id, value);
            // System.err.println("read #" + id + " = Integer[" + value
            // + "]");
            return 1;
        }

        case CONSTANT_Float: {
            float value = in.readFloat();
            constants.put(id, value);
            // System.err.println("read #" + id + " = Float[" + value +
            // "]");
            return 1;
        }

        case CONSTANT_Long: {
            long value = in.readLong();
            constants.put(id, value);
            // System.err.println("read #" + id + " = Long[" + value +
            // "]");
            return 2;
        }

        case CONSTANT_Double: {
            double value = in.readDouble();
            constants.put(id, value);
            // System.err.println("read #" + id + " = Double[" + value +
            // "]");
            return 2;
        }

        case CONSTANT_NameAndType: {
            int nameIndex = in.readUnsignedShort();
            int typeIndex = in.readUnsignedShort();
            NameAndTypeIndex value =
                new NameAndTypeIndex(nameIndex, typeIndex);
            nameAndTypeIndices.put(id, value);
            // System.err.println("read #" + id +
            // " = NameAndType[" + value + "]");
            return 1;
        }

        case CONSTANT_Utf8: {
            String value = in.readUTF();
            texts.put(id, value);
            // System.err.println("read #" + id + " = Utf8[" + value +
            // "]");
            return 1;
        }

        case CONSTANT_MethodType: {
            /* This does not contribute to the signatures, nor to the
             * runtime dependencies. */
            in.readUnsignedShort();
            return 1;
        }

        case CONSTANT_MethodHandle: {
            /* This does not contribute to the signatures, nor directly
             * to the runtime dependencies. */
            in.readUnsignedByte();
            in.readUnsignedShort();
            return 1;
        }

        case CONSTANT_InvokeDynamic: {
            /* This does not contribute to the signatures, nor directly
             * to the runtime dependencies. */
            in.readUnsignedShort();
            in.readUnsignedShort();
            return 1;
        }
        default:
            throw new IllegalArgumentException("CONSTANT type " + tag
                + " pos " + id);
        }
    }

    private class NameAndTypeIndex {
        final int name, type;

        NameAndTypeIndex(int name, int type) {
            this.name = name;
            this.type = type;
        }

        NameAndType resolve() {
            return new NameAndType(texts.get(name), texts.get(type));
        }

        public String toString() {
            return "#" + name + ".#" + type;
        }
    }

    private class RefIndex {
        final int clazz, nat;

        RefIndex(int clazz, int nat) {
            this.clazz = clazz;
            this.nat = nat;
        }

        Ref resolve(Map<? super Integer, ? extends ClassId> classes,
                    Map<? super Integer, ? extends NameAndType> nats) {
            return new Ref(classes.get(clazz), nats.get(nat));
        }

        public String toString() {
            return "#" + clazz + ".#" + nat;
        }
    }

    private final Map<Integer, Object> constants =
        new HashMap<Integer, Object>();

    private final Map<Integer, String> texts = new HashMap<Integer, String>();

    private final Map<Integer, Integer> stringIndices =
        new HashMap<Integer, Integer>();

    private final Map<Integer, Integer> classIndices =
        new HashMap<Integer, Integer>();

    private final Map<Integer, NameAndTypeIndex> nameAndTypeIndices =
        new HashMap<Integer, NameAndTypeIndex>();

    private final Map<Integer, RefIndex> fieldrefIndices =
        new HashMap<Integer, RefIndex>();

    private final Map<Integer, RefIndex> methodrefIndices =
        new HashMap<Integer, RefIndex>();

    private final Map<Integer, RefIndex> interfaceMethodrefIndices =
        new HashMap<Integer, RefIndex>();
}
