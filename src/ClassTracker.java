
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

import java.io.File;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;

@Deprecated
class ClassTracker implements Iterator<ClassId>, ClassSink {
    /* TODO: The parser uses assertions on classfile input. Assertions
     * are probably the wrong thing to use here. Throw a runtime
     * exception, e.g. IllegalArgumentException. */

    public ClassTracker(List<? extends File> sourcePath,
                        List<? extends File> classPath,
                        Collection<? extends ClassId> rootClasses) {
        this.sourcePath = new ArrayList<File>(sourcePath);
        this.classPath = new ArrayList<File>(classPath);
        for (ClassId clid : rootClasses)
            submit(clid);
    }

    @SuppressWarnings("unused")
    private final List<File> sourcePath;
    private final List<File> classPath;

    /* These classes have yet to be processed. */
    private final List<ClassId> outstanding = new LinkedList<ClassId>();

    /* This keeps track of classes we've made certain are outside our
     * source tree and need no further investigation. */
    private final Collection<ClassId> externals = new HashSet<ClassId>();

    /* These are classes established to be part of this source tree, and
     * have already been handled, or at least queued. */
    private final Collection<ClassId> internals = new HashSet<ClassId>();

    public Collection<ClassId> sourceClasses() {
        Collection<ClassId> result = new HashSet<ClassId>();
        for (ClassId clid : internals)
            result.add(clid.source());
        return Collections.unmodifiableCollection(result);
    }

    public Collection<ClassId> neededClasses() {
        return Collections.unmodifiableCollection(internals);
    }

    public Collection<String> importedPackages() {
        Collection<String> result = new HashSet<>();
        for (ClassId clid : externals) {
            String pkg = clid.getPackageName();
            if (pkg != null) result.add(pkg);
        }
        return result;
    }

    public Collection<String> providedPackages() {
        Collection<String> result = new HashSet<>();
        for (ClassId clid : internals) {
            String pkg = clid.getPackageName();
            if (pkg != null) result.add(pkg);
        }
        return result;
    }

    public void remove() {
        throw new UnsupportedOperationException("not implementable");
    }

    public boolean hasNext() {
        return !outstanding.isEmpty();
    }

    public ClassId next() {
        return outstanding.remove(0);
    }

    @Override
    public void submit(ClassId clid) {
        clid = clid.baseType();
        if (clid == null) return;

        /* Is the class known to be external? */
        if (externals.contains(clid)) return;

        /* Is the class known to be internal? */
        if (internals.contains(clid)) return;

        /* If it's internal, where should it be? */
        if (clid.findBinary(classPath) != null) {
            /* The class is internal. Record it as such. */
            internals.add(clid);

            /* Also set it as a job. */
            outstanding.add(clid);
        } else {
            /* The class is external. Record it as such, so we don't go
             * looking for it again. */
            externals.add(clid);
        }
    }

    private static int nextIn(String terms, CharSequence seq) {
        int i = 0;
        while (i < seq.length()) {
            if (terms.indexOf(seq.charAt(i)) > -1) return i;
            i++;
        }
        return i;
    }

    @Override
    public void submitMethodSignature(String text) {
        parseMethodTypeSignature(new StringBuilder(text));
    }

    @Override
    public void submitFieldSignature(String text) {
        parseFieldTypeSignature(new StringBuilder(text));
    }

    @Override
    public void submitClassSignature(String text) {
        parseClassSignature(new StringBuilder(text));
    }

    @Override
    public void submitTypeSignature(String text) {
        parseTypeSignature(new StringBuilder(text));
    }

    private boolean parseBaseType(StringBuilder buf) {
        if (buf.length() == 0) return false;
        switch (buf.charAt(0)) {
        case 'B':
        case 'C':
        case 'D':
        case 'F':
        case 'I':
        case 'J':
        case 'S':
        case 'Z':
            buf.deleteCharAt(0);
            return true;
        }
        return false;
    }

    private boolean parseClassSignature(StringBuilder buf) {
        if (buf.length() == 0) return false;
        if (buf.charAt(0) == '<') {
            buf.deleteCharAt(0);
            while (parseFormalTypeParameter(buf))
                ;
            assert buf.charAt(0) == '>';
            buf.deleteCharAt(0);
        }
        parseClassTypeSignature(buf); /* superclass */
        while (parseClassTypeSignature(buf))
            /* interfaces */
            ;
        return true;
    }

    private boolean parseFormalTypeParameter(StringBuilder buf) {
        if (buf.length() == 0) return false;
        if (buf.charAt(0) == '>') return false;
        int colon = nextIn(":", buf);
        buf.delete(0, colon);
        parseClassBound(buf);
        while (parseInterfaceBound(buf))
            ;
        return true;
    }

    private boolean parseClassBound(StringBuilder buf) {
        if (buf.length() == 0) return false;
        if (buf.charAt(0) != ':') return false;
        buf.deleteCharAt(0);
        parseFieldTypeSignature(buf);
        return true;
    }

    private boolean parseInterfaceBound(StringBuilder buf) {
        if (buf.length() == 0) return false;
        if (buf.charAt(0) != ':') return false;
        buf.deleteCharAt(0);
        parseFieldTypeSignature(buf);
        return true;
    }

    private boolean parseFieldTypeSignature(StringBuilder buf) {
        return parseClassTypeSignature(buf) || parseArrayTypeSignature(buf)
            || parseTypeVariableSignature(buf);
    }

    private boolean parseArrayTypeSignature(StringBuilder buf) {
        if (buf.length() == 0) return false;
        if (buf.charAt(0) != '[') return false;
        buf.deleteCharAt(0);
        parseTypeSignature(buf);
        return true;
    }

    private boolean parseTypeSignature(StringBuilder buf) {
        if (buf.length() == 0) return false;
        return parseBaseType(buf) || parseFieldTypeSignature(buf);
    }

    private boolean parseReturnType(StringBuilder buf) {
        if (buf.length() == 0) return false;
        if (buf.charAt(0) == 'V') {
            buf.deleteCharAt(0);
            return true;
        }
        parseTypeSignature(buf);
        return true;
    }

    private boolean parseTypeVariableSignature(StringBuilder buf) {
        if (buf.length() == 0) return false;
        if (buf.charAt(0) != 'T') return false;
        int semi = buf.indexOf(";");
        buf.delete(0, semi + 1);
        return true;
    }

    private boolean parseClassTypeSignature(StringBuilder buf) {
        if (buf.length() == 0) return false;
        if (buf.charAt(0) != 'L') return false;
        buf.deleteCharAt(0);
        // StringBuilder packageBuf = new StringBuilder();
        int min = nextIn(";<.", buf);
        int slash = buf.lastIndexOf("/", min);
        final String packageName;
        if (slash < 0) {
            packageName = "";
        } else {
            packageName = buf.substring(0, slash + 1);
            buf.delete(0, slash + 1);
        }
        parseSimpleClassTypeSignatures(packageName, buf);
        return true;
    }

    private void parseSimpleClassTypeSignatures(String packageName,
                                                StringBuilder buf) {
        for (;;) {
            int min = nextIn(";<.", buf);
            String className = packageName + buf.substring(0, min);
            submit(ClassId.forName(className));
            buf.delete(0, min);
            if (buf.charAt(0) == '<') {
                buf.deleteCharAt(0);
                while (parseTypeArgument(buf))
                    ;
                assert buf.charAt(0) == '>';
                buf.deleteCharAt(0);
            }
            if (buf.charAt(0) == '.') {
                buf.deleteCharAt(0);
                packageName = className + '$';
                continue;
            }
            assert buf.charAt(0) == ';';
            buf.deleteCharAt(0);
            return;
        }
    }

    private boolean parseTypeArgument(StringBuilder buf) {
        if (buf.length() == 0) return false;
        if (buf.charAt(0) == '*') {
            buf.deleteCharAt(0);
            return true;
        }
        if (buf.charAt(0) == '+' || buf.charAt(0) == '-') {
            buf.deleteCharAt(0);
            parseFieldTypeSignature(buf);
            return true;
        }
        return parseFieldTypeSignature(buf);
    }

    private boolean parseMethodTypeSignature(StringBuilder buf) {
        if (buf.length() == 0) return false;
        if (buf.charAt(0) == '<') {
            buf.deleteCharAt(0);
            while (parseFormalTypeParameter(buf))
                ;
            assert buf.charAt(0) == '>';
            buf.deleteCharAt(0);
        }
        assert buf.charAt(0) == '(';
        buf.deleteCharAt(0);
        while (parseTypeSignature(buf))
            ;
        assert buf.length() > 0;
        assert buf.charAt(0) == ')';
        buf.deleteCharAt(0);
        parseReturnType(buf);
        while (parseThrowsSignature(buf))
            ;
        return true;
    }

    private boolean parseThrowsSignature(StringBuilder buf) {
        if (buf.length() == 0) return false;
        if (buf.charAt(0) != '^') return false;
        buf.deleteCharAt(0);
        if (!parseTypeVariableSignature(buf)) parseClassTypeSignature(buf);
        return true;
    }
}
