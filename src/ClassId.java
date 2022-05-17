
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
import java.util.Arrays;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Immutably identifies a class type. This includes plain classes and
 * interfaces, arrays of classes and interfaces, and arrays of
 * primitives, but not primitives themselves.
 * 
 * @author simpsons
 */
class ClassId implements Comparable<ClassId> {
    private final String[] parts;
    private final String text;
    private final boolean anonymous;
    private final int depth;
    private final boolean primitive;

    /**
     * Parse a class identifier from a string. Formats according to the
     * following examples are accepted:
     * 
     * <ul>
     * 
     * <li><samp>java/lang/String</samp> &mdash; a simple class
     * 
     * <li><samp>Ljava/lang/String;</samp> &mdash; a 1-dimensional array
     * of objects; the number of <samp>L</samp>s specifies the number of
     * dimensions.
     * 
     * <li><samp>LB</samp> &mdash; a 1-dimensional array of bytes; other
     * primitive types are recognized, as are multidimensional array
     * types.
     * 
     * </ul>
     * 
     * <p>
     * Note that primitive types are not represented, as these are not
     * identified by any class identifier.
     * 
     * @param text the text to be parsed
     * 
     * @return the class identifier for the given string
     * 
     * @throws IllegalArgumentException if the text does not match a
     * known identifier format
     */
    public static ClassId forName(String text) {
        if (text == null) return null;
        Matcher m = arrayPattern.matcher(text);
        if (!m.matches())
            throw new IllegalArgumentException("Not class: " + text);
        assert m.matches();
        if (m.group(5) != null) return new ClassId(0, m.group(5));
        if (m.group(3) != null)
            return new ClassId(m.group(3).length(), m.group(4).charAt(0));
        return new ClassId(m.group(1).length(), m.group(2));
    }

    private static final Pattern arrayPattern = Pattern
        .compile("^(?:(\\[+)L(.*);)|(?:(\\[+)([ZCSIJBFD]))|([^\\[].*)$");

    private static final Pattern anonPattern = Pattern.compile(".*\\$[0-9]");

    private static boolean isAnonymous(String leaf) {
        return anonPattern.matcher(leaf).matches();
    }

    /**
     * Get the number of array dimensions.
     * 
     * @return the number of array dimensions
     */
    public int arrayDimensions() {
        return depth;
    }

    /**
     * Determine whether the represented type is an array type.
     * 
     * @return true if this is an array type
     */
    public boolean isArray() {
        return depth > 0;
    }

    private ClassId(int depth, char primitiveType) {
        this.depth = depth;
        this.primitive = true;
        this.parts = new String[] { Character.toString(primitiveType) };
        this.anonymous = false;
        StringBuilder textBuilder = new StringBuilder();
        for (int i = 0; i < depth; i++)
            textBuilder.append('[');
        textBuilder.append(primitiveType);
        this.text = textBuilder.toString();
    }

    /**
     * 
     * @param depth the array depth
     * 
     * @param rest This must be a slash-separated class name.
     */
    private ClassId(int depth, String rest) {
        this(depth, slashSep.split(rest));
    }

    private ClassId(int depth, final String[] parts) {
        this.primitive = false;
        this.depth = depth;
        this.parts = parts;
        this.anonymous = isAnonymous(parts[parts.length - 1]);
        StringBuilder textBuilder = new StringBuilder();
        if (depth > 0) {
            for (int i = 0; i < depth; i++)
                textBuilder.append('[');
            textBuilder.append('L');
        }
        String sep = "";
        for (String part : parts) {
            textBuilder.append(sep);
            sep = "/";
            textBuilder.append(part);
        }
        this.text = textBuilder.toString();
    }

    /**
     * Get the base type of this class. If this is an array of
     * primitives, return {@code null}. If this is an array type, return
     * the primary element type. Otherwise, return this type.
     * 
     * @return the base type of this class, or {@code null} if this is
     * an array of primitives
     */
    public ClassId baseType() {
        if (depth == 0) return this;
        if (baseIsPrimitive()) return null;
        return new ClassId(0, parts);
    }

    /**
     * Get the primary element type.
     * 
     * @return the primary element type, or {@code null} if this is not
     * an array type, or the base type is primitive
     */
    public ClassId primaryElementType() {
        if (depth == 0) return null;
        if (baseIsPrimitive()) return null;
        return new ClassId(0, parts);
    }

    /**
     * Get the element type.
     * 
     * @return the element type, or {@code null} if this is not an array
     * type, or this is a 1-dimensional array type of primitives
     */
    public ClassId elementType() {
        if (depth == 0) return null;
        if (depth == 1 && baseIsPrimitive()) return null;
        return new ClassId(depth - 1, parts);
    }

    /**
     * Get an array type.
     * 
     * @param depth the number of additional dimensions
     * 
     * @return an array type with this types dimensions plus the
     * specified extra dimensions
     * 
     * @throws IllegalArgumentException if the depth is negative
     */
    public ClassId arrayType(int depth) {
        if (depth < 0)
            throw new IllegalArgumentException("Negative depth: " + depth);
        if (depth == 0) return this;
        if (baseIsPrimitive())
            return new ClassId(this.depth + depth, parts[0].charAt(0));
        return new ClassId(this.depth + depth, parts);
    }

    /**
     * Test whether this type is anonymous. This is the case if the
     * class is nested, and its simple name is a number.
     * 
     * @return true if this type is anonymous
     */
    public boolean isAnonymous() {
        return anonymous;
    }

    /**
     * Test whether the base type is a primitive type.
     * 
     * @return true if the base type is primitive
     */
    public boolean baseIsPrimitive() {
        return primitive;
    }

    /**
     * Get the internal name of this class. For a plain class or
     * interface type, this is the full class name, using slashes to
     * separate elements of the package name, and using dollars to
     * separate enclosing classes from their inner components.
     * 
     * @return the internal name of this class
     */
    @Override
    public String toString() {
        return text;
    }

    @Override
    public int hashCode() {
        return text.hashCode();
    }

    public boolean equals(Object o) {
        if (o instanceof ClassId) {
            ClassId other = (ClassId) o;
            return text.equals(other.text);
        }
        return false;
    }

    @Override
    public int compareTo(ClassId other) {
        return text.compareTo(other.text);
    }

    /**
     * Get the external name of the identified class. This is identical
     * to its internal name, but with slashes replaced with dots.
     * 
     * @return the class's external name
     */
    public String toExternalName() {
        return text.replace('/', '.');
    }

    private static final Pattern slashSep = Pattern.compile("[./]");

    /**
     * Get the top-level class defining this class.
     * 
     * @return the top-level class defining this class, which could be
     * this class if it is top-level
     */
    public ClassId source() {
        int last = parts.length - 1;
        int dollar = parts[last].indexOf('$');
        if (dollar < 0) return this;

        String[] newParts = new String[parts.length];
        System.arraycopy(parts, 0, newParts, 0, last);
        newParts[last] = parts[last].substring(0, dollar);
        return new ClassId(0, newParts);
    }

    private String[] leaves(String suffix) {
        int last = parts.length - 1;
        String[] newParts = new String[parts.length];
        System.arraycopy(parts, 0, newParts, 0, last);
        newParts[last] = parts[last] + suffix;
        return newParts;
    }

    private String[] sourceLeaves() {
        /* TODO: Why not call source().leaves("java")? */
        return leaves(".java");
    }

    private String[] binaryLeaves() {
        return leaves(".class");
    }

    /**
     * Given a root directory, determine the name of the source file
     * containing this class. This makes no attempt to correct for
     * nested classes.
     * 
     * @param path the root directory
     * 
     * @return the filename of the source file containing the class, or
     * {@code null} if this is of array type
     */
    public File sourceFile(File path) {
        if (isArray() || baseIsPrimitive()) return null;
        /* TODO: Why not call source().sourceLeaves(), or get
         * sourceLeaves() to do it? */
        return walk(path, sourceLeaves());
    }

    /**
     * Given a root directory, determine the name of the class file
     * containing this class.
     * 
     * @param path the root directory
     * 
     * @return the filename of the class file containing the class, or
     * {@code null} if this is of array type
     */
    public File binaryFile(File path) {
        if (isArray() || baseIsPrimitive()) return null;
        return walk(path, binaryLeaves());
    }

    private static File walk(File root, String[] leaves) {
        for (String leaf : leaves)
            root = new File(root, leaf);
        return root;
    }

    private static File find(Iterable<? extends File> paths,
                             String[] leaves) {
        for (File p : paths) {
            File cand = walk(p, leaves);
            if (cand.exists()) return cand;
        }
        return null;
    }

    /**
     * Find a source file for this class.
     * 
     * @param paths a series of root directories in which to search
     * 
     * @return the name of the first file found that should contain this
     * class's source, or {@code null} if not found or this type is an
     * array
     */
    public File findSource(Iterable<? extends File> paths) {
        if (isArray() || baseIsPrimitive()) return null;
        /* TODO: Why not call source().sourceLeaves(), or get
         * sourceLeaves() to do it? */
        return find(paths, sourceLeaves());
    }

    /**
     * Find a class file for this class.
     * 
     * @param paths a series of root directories in which to search
     * 
     * @return the name of the first file found that should contain this
     * class's bytecode, or {@code null} if not found or this type is an
     * array
     */
    public File findBinary(Iterable<? extends File> paths) {
        if (isArray() || baseIsPrimitive()) return null;
        return find(paths, binaryLeaves());
    }

    /**
     * Get the name of this class's package.
     * 
     * @return the dot-separated name of this class's package, or
     * {@code null} if it does not belong to a package
     */
    public String getPackageName() {
        final int len = parts.length;
        if (len < 2) return null;
        StringBuilder out = new StringBuilder(parts[0]);
        for (String s : Arrays.asList(parts).subList(1, len - 1))
            out.append('.').append(s);
        return out.toString();
    }
}
