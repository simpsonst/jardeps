
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
import java.util.Collections;
import java.util.Map;

class ConstantPool {
    ConstantPool(Map<Integer, Object> constants,
                 Map<Integer, NameAndType> nats, Map<Integer, String> texts,
                 Map<Integer, String> strings, Map<Integer, ClassId> classes,
                 Map<Integer, Ref> fieldrefs, Map<Integer, Ref> methodrefs,
                 Map<Integer, Ref> interfaceMethodrefs) {
        this.constants = constants;
        this.nats = nats;
        this.texts = texts;
        this.strings = strings;
        this.classes = classes;
        this.fieldrefs = fieldrefs;
        this.methodrefs = methodrefs;
        this.interfaceMethodrefs = interfaceMethodrefs;
    }

    static ConstantPool build(DataInput in) throws IOException {
        return new ConstantPoolBuilder().read(in);
    }

    Object getConstant(int id) {
        if (!constants.containsKey(id))
            throw new IllegalArgumentException("constant missing: " + id);
        return constants.get(id);
    }

    NameAndType getNameAndType(int id) {
        if (!nats.containsKey(id))
            throw new IllegalArgumentException("NameAndType missing: " + id);
        return nats.get(id);
    }

    String getString(int id) {
        if (!strings.containsKey(id))
            throw new IllegalArgumentException("string missing: " + id);
        return strings.get(id);
    }

    String getText(int id) {
        if (!texts.containsKey(id))
            throw new IllegalArgumentException("text missing: " + id);
        return texts.get(id);
    }

    Iterable<ClassId> getClasses() {
        return Collections.unmodifiableCollection(classes.values());
    }

    ClassId getClass(int id) {
        if (!classes.containsKey(id))
            throw new IllegalArgumentException("class missing: " + id);
        return classes.get(id);
    }

    Ref getField(int id) {
        if (!fieldrefs.containsKey(id))
            throw new IllegalArgumentException("field missing: " + id);
        return fieldrefs.get(id);
    }

    Ref getMethod(int id) {
        if (!methodrefs.containsKey(id))
            throw new IllegalArgumentException("method missing: " + id);
        return methodrefs.get(id);
    }

    Ref getInterfaceMethod(int id) {
        if (!interfaceMethodrefs.containsKey(id))
            throw new IllegalArgumentException("interface method missing: "
                + id);
        return interfaceMethodrefs.get(id);
    }

    private final Map<Integer, Object> constants;

    private final Map<Integer, NameAndType> nats;

    private final Map<Integer, String> texts;

    private final Map<Integer, String> strings;

    private final Map<Integer, ClassId> classes;

    private final Map<Integer, Ref> fieldrefs;

    private final Map<Integer, Ref> methodrefs;

    private final Map<Integer, Ref> interfaceMethodrefs;
}
