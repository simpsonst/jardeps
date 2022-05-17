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

package uk.ac.lancs.scc.jardeps.apt;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import javax.annotation.processing.AbstractProcessor;
import javax.annotation.processing.ProcessingEnvironment;
import javax.annotation.processing.RoundEnvironment;
import javax.lang.model.SourceVersion;
import javax.lang.model.element.Element;
import javax.lang.model.element.ElementKind;
import javax.lang.model.element.ExecutableElement;
import javax.lang.model.element.Modifier;
import javax.lang.model.element.Name;
import javax.lang.model.element.TypeElement;
import javax.lang.model.element.VariableElement;
import javax.lang.model.type.MirroredTypesException;
import javax.lang.model.type.TypeKind;
import javax.lang.model.type.TypeMirror;
import javax.lang.model.util.ElementFilter;
import javax.lang.model.util.Elements;
import javax.lang.model.util.Types;
import javax.tools.Diagnostic.Kind;
import uk.ac.lancs.scc.jardeps.Application;
import uk.ac.lancs.scc.jardeps.Service;

public class ServiceProcessor extends AbstractProcessor {
    private static final String OUTDIR_OPTION =
        "uk.ac.lancs.scc.jardeps.service.dir";

    private static final String MANIFEST_OPTION =
        "uk.ac.lancs.scc.jardeps.manifest";

    private ProcessingEnvironment env;

    private Types typeUtils;

    private Elements elemUtils;

    private Map<Name, Collection<Name>> table = new HashMap<>();

    private Collection<TypeElement> goodApplications = new HashSet<>();

    private Collection<TypeElement> badApplications = new HashSet<>();

    @Override
    public Set<String> getSupportedOptions() {
        return new HashSet<>(Arrays.asList(OUTDIR_OPTION, MANIFEST_OPTION));
    }

    @Override
    public Set<String> getSupportedAnnotationTypes() {
        return new HashSet<>(Arrays.asList(Service.class.getName(),
                                           Application.class.getName()));
    }

    @Override
    public SourceVersion getSupportedSourceVersion() {
        return env.getSourceVersion();
    }

    @Override
    public void init(ProcessingEnvironment processingEnv) {
        env = processingEnv;
        typeUtils = env.getTypeUtils();
        elemUtils = env.getElementUtils();
    }

    private void writeTable() {
        /* Find out where to store the table. Clear all files within it
         * first. */
        String dirName = env.getOptions().get(OUTDIR_OPTION);
        if (dirName != null) {
            File dir = new File(dirName);
            for (File file : dir.listFiles())
                file.delete();

            /* Store each key as a filename, and each value as a line in
             * the file. */
            for (Map.Entry<Name, Collection<Name>> entry : table.entrySet()) {
                Name key = entry.getKey();
                File file = new File(dir, key.toString());
                try (PrintWriter out =
                    new PrintWriter(new OutputStreamWriter(new FileOutputStream(file),
                                                           StandardCharsets.UTF_8))) {
                    for (Name value : entry.getValue())
                        out.println(value);
                } catch (IOException ex) {
                    env.getMessager().printMessage(Kind.ERROR,
                                                   "Could not open " + file
                                                       + ": "
                                                       + ex.getMessage());
                }
            }
        }

        if (goodApplications.size() + badApplications.size() > 1)
            env.getMessager().printMessage(Kind.ERROR,
                                           "more than one application"
                                               + " entry point specified");
        String manName = env.getOptions().get(MANIFEST_OPTION);
        if (manName != null) {
            File file = new File(manName);
            try (PrintWriter out =
                new PrintWriter(new OutputStreamWriter(new FileOutputStream(file),
                                                       StandardCharsets.UTF_8))) {
                if (goodApplications.size() == 1 && badApplications.isEmpty()) {
                    out.printf("Main-Class: %s%n",
                               goodApplications.iterator().next()
                                   .getQualifiedName());
                }
            } catch (IOException ex) {
                env.getMessager().printMessage(Kind.ERROR,
                                               "Could not open " + file + ": "
                                                   + ex.getMessage());
            }
        }
    }

    @Override
    public boolean process(Set<? extends TypeElement> annotations,
                           RoundEnvironment roundEnv) {
        if (roundEnv.processingOver()) {
            writeTable();
            return false;
        }

        /* Search for applications. */
        TypeMirror argType = env.getTypeUtils().getArrayType(env
            .getElementUtils().getTypeElement("java.lang.String").asType());
        for (Element elem : roundEnv
            .getElementsAnnotatedWith(Application.class)) {
            assert elem.getKind() == ElementKind.CLASS;
            TypeElement typeElem = (TypeElement) elem;
            boolean typeOkay = false;
            for (ExecutableElement e : ElementFilter
                .methodsIn(typeElem.getEnclosedElements())) {
                /* See if this is the right method. It must be called
                 * 'main', and have one argument of type String[]. */
                if (!e.getSimpleName().toString().equals("main")) continue;
                List<? extends VariableElement> args = e.getParameters();
                if (args.size() != 1) continue;
                TypeMirror a0 = args.get(0).asType();
                if (!env.getTypeUtils().isSameType(a0, argType)) continue;

                /* This must be the method, but is it suitable? */
                boolean okay = true;
                if (e.getReturnType().getKind() != TypeKind.VOID) {
                    env.getMessager().printMessage(Kind.ERROR,
                                                   "application entry point"
                                                       + " must return void",
                                                   e);
                    okay = false;
                }
                Set<Modifier> m = e.getModifiers();
                if (!m.contains(Modifier.PUBLIC)) {
                    env.getMessager().printMessage(Kind.ERROR,
                                                   "application entry point"
                                                       + " must be public",
                                                   e);
                    okay = false;
                }
                if (!m.contains(Modifier.STATIC)) {
                    env.getMessager().printMessage(Kind.ERROR,
                                                   "application entry point"
                                                       + " must be static",
                                                   e);
                    okay = false;
                }
                if (m.contains(Modifier.ABSTRACT)) {
                    env.getMessager()
                        .printMessage(Kind.ERROR,
                                      "application entry point"
                                          + " must not be abstract",
                                      e);
                    okay = false;
                }

                Application s = elem.getAnnotation(Application.class);
                if (okay) {
                    if (s.value()) goodApplications.add(typeElem);
                    typeOkay = true;
                } else {
                    if (s.value()) badApplications.add(typeElem);
                }

                break;
            }
            if (!typeOkay) {
                env.getMessager().printMessage(Kind.ERROR,
                                               "class unsuitable as"
                                                   + " application entry point;"
                                                   + " no public static"
                                                   + " void main(String[])",
                                               elem);
            }
        }

        /* Search for services. */
        for (Element elem : roundEnv.getElementsAnnotatedWith(Service.class)) {
            assert elem.getKind() == ElementKind.CLASS;
            TypeElement typeElem = (TypeElement) elem;
            Service s = elem.getAnnotation(Service.class);
            Name value = elemUtils.getBinaryName(typeElem);
            Collection<TypeMirror> matches = new HashSet<>();
            addHierarchy(matches, typeElem.getSuperclass());
            addHierarchy(matches, typeElem.getInterfaces());
            try {
                s.value();
            } catch (MirroredTypesException ex) {
                for (TypeMirror mir : ex.getTypeMirrors()) {
                    mir = typeUtils.erasure(mir);
                    TypeElement st = (TypeElement) typeUtils.asElement(mir);
                    Name key = elemUtils.getBinaryName(st);
                    if (!matches.contains(mir)) {
                        String message = "Service type " + key
                            + " is not implemented/extendedx";
                        env.getMessager()
                            .printMessage(Kind.ERROR, message, elem);
                    }
                    Collection<Name> values = table.get(key);
                    if (values == null) {
                        values = new HashSet<>();
                        table.put(key, values);
                    }
                    values.add(value);
                }
            }
        }
        return false;
    }

    private void addHierarchy(Collection<? super TypeMirror> into,
                              Collection<? extends TypeMirror> types) {
        for (TypeMirror tm : types)
            addHierarchy(into, tm);
    }

    private void addHierarchy(Collection<? super TypeMirror> into,
                              TypeMirror type) {
        /* Erase generics. */
        type = typeUtils.erasure(type);

        /* Add the specified type to the collection. If it is already in
         * the collection, job done. */
        if (!into.add(type)) return;

        /* Try adding the superclass and extended/implemented interfaces
         * too. */
        TypeElement st = (TypeElement) typeUtils.asElement(type);
        if (st == null) return;
        addHierarchy(into, st.getSuperclass());
        addHierarchy(into, st.getInterfaces());
    }
}
