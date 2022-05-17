
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

import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintWriter;
import java.io.Reader;
import java.net.URI;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.ListIterator;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Pattern;

import javax.tools.FileObject;
import javax.tools.ForwardingJavaFileManager;
import javax.tools.ForwardingJavaFileObject;
import javax.tools.JavaCompiler;
import javax.tools.JavaCompiler.CompilationTask;
import javax.tools.JavaFileManager;
import javax.tools.JavaFileObject;
import javax.tools.JavaFileObject.Kind;
import javax.tools.OptionChecker;
import javax.tools.StandardJavaFileManager;
import javax.tools.StandardLocation;
import javax.tools.ToolProvider;

public final class JardepsCompiler {
    private static class ExtraArgs implements OptionChecker {
        public List<String> sourceCommand;
        public List<String> classCommand;
        public List<String> inputCommand;
        public File apiFile;
        public File ppiFile;
        public File usedPackagesFile;
        public File providedPackagesFile;

        @Override
        public int isSupportedOption(String arg0) {
            if ("-profile:public".equals(arg0)) return 1;
            if ("-profile:default".equals(arg0)) return 1;
            if ("-packages:provided".equals(arg0)) return 1;
            if ("-packages:used".equals(arg0)) return 1;
            if (arg0.startsWith("-list:sources:"))
                return Integer.parseInt(arg0.substring(14)) + 1;
            if (arg0.startsWith("-list:inputs:"))
                return Integer.parseInt(arg0.substring(13)) + 1;
            if (arg0.startsWith("-list:classes:"))
                return Integer.parseInt(arg0.substring(14)) + 1;
            return -1;
        }

        public void applyOptions(Iterable<? extends String> coll) {
            for (Iterator<? extends String> iter = coll.iterator(); iter
                .hasNext();) {
                String arg0 = iter.next();

                if ("-profile:public".equals(arg0)) {
                    apiFile = new File(iter.next());
                    continue;
                }

                if ("-profile:default".equals(arg0)) {
                    ppiFile = new File(iter.next());
                    continue;
                }

                if ("-packages:provided".equals(arg0)) {
                    providedPackagesFile = new File(iter.next());
                    continue;
                }

                if ("-packages:used".equals(arg0)) {
                    usedPackagesFile = new File(iter.next());
                    continue;
                }

                if (arg0.startsWith("-list:sources:")) {
                    int amount = Integer.parseInt(arg0.substring(14)) + 1;
                    sourceCommand = new ArrayList<>(amount);
                    while (amount > 0) {
                        sourceCommand.add(iter.next());
                        amount--;
                    }
                    continue;
                }

                if (arg0.startsWith("-list:inputs:")) {
                    int amount = Integer.parseInt(arg0.substring(13)) + 1;
                    inputCommand = new ArrayList<>(amount);
                    while (amount > 0) {
                        inputCommand.add(iter.next());
                        amount--;
                    }
                    continue;
                }

                if (arg0.startsWith("-list:classes:")) {
                    int amount = Integer.parseInt(arg0.substring(14)) + 1;
                    classCommand = new ArrayList<>(amount);
                    while (amount > 0) {
                        classCommand.add(iter.next());
                        amount--;
                    }
                    continue;
                }
            }
        }
    }

    private static void expandAtArgs(List<String> args) throws IOException {
        for (ListIterator<String> iter = args.listIterator(); iter
            .hasNext();) {
            String arg = iter.next();
            if (arg.length() == 0) continue;
            if (arg.charAt(0) != '@') continue;
            iter.remove();
            try (BufferedReader in =
                new BufferedReader(new FileReader(arg.substring(1)))) {
                for (String line = in.readLine(); line != null; line =
                    in.readLine())
                    iter.add(line);
            }
        }
    }

    private static final String OPT_BAD_SWITCHES = "g|X(lint|doclint)";
    private static final String REQ_BAD_SWITCHES =
        "implicit|proc|bootclasspath(/[ap])?|X(diags|pkginfo|plugin|prefer)";
    private static final Pattern badSwitches = Pattern.compile("^-((("
        + OPT_BAD_SWITCHES + ")(:.*|$))|((" + REQ_BAD_SWITCHES + "):.*))");

    public static void
        main(String[] args) throws IOException, InterruptedException {
        /* Create basic components. */
        JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
        OptionChecker classList = new OptionChecker() {
            @Override
            public int isSupportedOption(String option) {
                return 0;
            }

            @Override
            public String toString() {
                return "classList";
            }
        };
        ExtraArgs extras = new ExtraArgs() {
            @Override
            public String toString() {
                return "extras";
            }
        };
        final Collection<ClassId> generatedFiles = new TreeSet<>();
        final Collection<ClassId> usedSourceFiles = new TreeSet<>();
        final Collection<URI> inputFiles = new TreeSet<>();
        final Collection<URI> outputFiles = new TreeSet<>();

        /* Create a way to monitor which files are used and
         * generated. */
        try (
            StandardJavaFileManager fm =
                compiler.getStandardFileManager(null, null, null);
            JavaFileManager monitor =
                new Monitor(fm, generatedFiles, usedSourceFiles, inputFiles,
                            outputFiles) {
                    @Override
                    public String toString() {
                        return "monitor";
                    }
                }) {

            /* Assign arguments to components that accept them. */
            Map<OptionChecker, List<String>> arguments =
                new LinkedHashMap<>();
            arguments.put(compiler, new ArrayList<String>());
            arguments.put(monitor, new ArrayList<String>());
            arguments.put(extras, new ArrayList<String>());
            arguments.put(classList, new ArrayList<String>());
            for (Iterator<String> iter = Arrays.asList(args).iterator(); iter
                .hasNext();) {
                String arg = iter.next();
                for (Map.Entry<OptionChecker, List<String>> item : arguments
                    .entrySet()) {
                    OptionChecker checker = item.getKey();
                    int count = checker.isSupportedOption(arg);
                    if (count < 0) continue;
                    /* Detect potentially faulty switches. */
                    if (count > 0 && badSwitches.matcher(arg).matches())
                        count = 0;
                    if (false && count > 0) System.err
                        .printf("%s claims %d for %s%n", arg, count, checker);
                    List<String> coll = item.getValue();
                    coll.add(arg);
                    while (count > 0) {
                        if (!iter.hasNext())
                            throw new NoSuchElementException("Parsing " + arg
                                + " requiring " + count
                                + " further arguments");
                        coll.add(iter.next());
                        count--;
                    }
                    break;
                }
            }

            /* Resolve @ arguments in the file list. */
            expandAtArgs(arguments.get(classList));

            /* Pass our extension options. */
            extras.applyOptions(arguments.get(extras));

            /* Pass options to the file manager. */
            for (Iterator<String> iter =
                arguments.get(monitor).iterator(); iter.hasNext();) {
                String first = iter.next();
                boolean status = monitor.handleOption(first, iter);
                assert status;
            }

            Iterable<? extends JavaFileObject> explicitSources =
                fm.getJavaFileObjectsFromStrings(arguments.get(classList));
            if (!arguments.get(classList).isEmpty()) {
                /* Prepare for compilation. */
                CompilationTask task = compiler
                    .getTask(null, monitor, null, arguments.get(compiler),
                             null, explicitSources);

                /* Compile. */
                boolean okay = task.call();

                /* Report failure. */
                if (!okay) System.exit(1);
            }

            /* Prepare to generate resources on demand. */
            Resources resources = new Resources(fm, generatedFiles);

            /* Run an external command to deal with the list of source
             * files used in this build. */
            if (extras.sourceCommand != null) {
                /* Include the explicit sources in the list of source
                 * files. */
                for (JavaFileObject item : explicitSources) {
                    ClassId clid = ClassId.forName(monitor
                        .inferBinaryName(StandardLocation.SOURCE_PATH, item));
                    usedSourceFiles.add(clid);
                }

                for (ClassId clid : usedSourceFiles)
                    extras.sourceCommand.add(clid.toString());
                ProcessBuilder builder =
                    new ProcessBuilder(extras.sourceCommand);
                builder.environment().putAll(System.getenv());
                builder.redirectError(ProcessBuilder.Redirect.INHERIT);
                builder.redirectOutput(ProcessBuilder.Redirect.INHERIT);
                Process proc = builder.start();
                proc.getOutputStream().close();
                int rc = proc.waitFor();
                if (rc != 0)
                    System.err.printf("Warning: -list:sources command"
                        + " returned %d%n", rc);
            }

            /* Run an external command to deal with the list of non-Java
             * input files used in this build. */
            if (extras.inputCommand != null) {
                Path here = Paths.get("").toAbsolutePath();
                for (URI loc : inputFiles) {
                    Path pt = here.relativize(Paths.get(loc));
                    extras.inputCommand.add(pt.toString());
                }
                ProcessBuilder builder =
                    new ProcessBuilder(extras.inputCommand);
                builder.environment().putAll(System.getenv());
                builder.redirectError(ProcessBuilder.Redirect.INHERIT);
                builder.redirectOutput(ProcessBuilder.Redirect.INHERIT);
                Process proc = builder.start();
                proc.getOutputStream().close();
                int rc = proc.waitFor();
                if (rc != 0) System.err.printf("Warning: -list:inputs command"
                    + " returned %d%n", rc);
            }

            /* Run an external command to deal with the list of classes
             * generated in this build. */
            if (extras.classCommand != null) {
                for (ClassId clid : generatedFiles)
                    extras.classCommand.add(clid.toString());
                extras.classCommand.add("--");
                Path here = Paths.get("").toAbsolutePath();
                for (URI loc : outputFiles) {
                    Path pt = here.relativize(Paths.get(loc));
                    extras.classCommand.add(pt.toString());
                }
                ProcessBuilder builder =
                    new ProcessBuilder(extras.classCommand);
                builder.environment().putAll(System.getenv());
                builder.redirectError(ProcessBuilder.Redirect.INHERIT);
                builder.redirectOutput(ProcessBuilder.Redirect.INHERIT);
                Process proc = builder.start();
                proc.getOutputStream().close();
                int rc = proc.waitFor();
                if (rc != 0)
                    System.err.printf("Warning: -list:classes command"
                        + " returned %d%n", rc);
            }

            /* Generate a list of packages of all generated classes. */
            if (extras.providedPackagesFile != null) {
                Collection<String> providedPackages = new HashSet<>();
                for (ClassId clid : generatedFiles) {
                    String pkg = clid.getPackageName();
                    if (pkg == null) continue;
                    providedPackages.add(pkg);
                }
                try (PrintWriter out =
                    new PrintWriter(new FileWriter(extras.providedPackagesFile))) {
                    for (String pkg : providedPackages)
                        out.println(pkg);
                }
            }

            /* Generate a list of packages referenced by classed
             * compiled in this build. */
            if (extras.usedPackagesFile != null) {
                Collection<ClassId> runtimeClasses = new HashSet<>();
                resources.getRuntimeClasses(runtimeClasses);
                Collection<ClassId> externals = new TreeSet<>(runtimeClasses);
                externals.removeAll(generatedFiles);
                Collection<String> packages = new HashSet<>();
                for (ClassId clid : externals) {
                    String pkg = clid.getPackageName();
                    if (pkg != null) packages.add(pkg);
                }
                try (PrintWriter out =
                    new PrintWriter(new FileWriter(extras.usedPackagesFile))) {
                    for (String pkg : packages)
                        out.println(pkg);
                }
            }

            /* Generate the public and default profiles if requested. */
            if (extras.apiFile != null || extras.ppiFile != null) {
                /* Compute the signatures and record all referenced
                 * classes. */
                List<String> publicMemberLines = new ArrayList<>();
                List<String> packageMemberLines = new ArrayList<>();
                resources.getProfiles(publicMemberLines, packageMemberLines);

                if (extras.apiFile != null) {
                    Collections.sort(publicMemberLines);
                    try (PrintWriter out =
                        new PrintWriter(new FileWriter(extras.apiFile))) {
                        for (String line : publicMemberLines)
                            out.println(line);
                    }
                }
                if (extras.ppiFile != null) {
                    Collections.sort(packageMemberLines);
                    try (PrintWriter out =
                        new PrintWriter(new FileWriter(extras.ppiFile))) {
                        for (String line : packageMemberLines)
                            out.println(line);
                    }
                }
            }
        }
    }

    private static class Resources {
        private final Collection<ClassId> generatedFiles;
        private final StandardJavaFileManager fileManager;

        public Resources(StandardJavaFileManager fileManager,
                         Collection<ClassId> generatedFiles) {
            this.fileManager = fileManager;
            this.generatedFiles = generatedFiles;
        }

        private Map<ClassId, ClassAnalysis> analyses;

        private void doAnalyses() throws IOException {
            if (analyses != null) return;
            analyses = new HashMap<>();
            for (ClassId clid : generatedFiles) {
                String className = clid.toString();
                JavaFileObject fo = fileManager
                    .getJavaFileForInput(StandardLocation.CLASS_OUTPUT,
                                         className, Kind.CLASS);
                try (DataInputStream in =
                    new DataInputStream(fo.openInputStream())) {
                    ClassAnalysis anal = new ClassAnalysis();
                    anal.load(clid, in);
                    analyses.put(clid, anal);
                }
            }
        }

        public void getProfiles(Collection<? super String> publicMemberLines,
                                Collection<? super String> packageMemberLines)
            throws IOException {
            doAnalyses();
            for (ClassAnalysis anal : analyses.values()) {
                anal.createProfiles(publicMemberLines, packageMemberLines);
            }
        }

        public void getRuntimeClasses(Collection<? super ClassId> into)
            throws IOException {
            doAnalyses();
            for (ClassAnalysis anal : analyses.values()) {
                anal.getRuntimeClassReferences(into);
            }
        }
    }

    private static class Monitor
        extends ForwardingJavaFileManager<StandardJavaFileManager> {

        private final Collection<ClassId> generatedFiles;
        private final Collection<ClassId> usedSourceFiles;
        private final Collection<URI> inputFiles;
        private final Collection<URI> outputFiles;

        public Monitor(StandardJavaFileManager fileManager,
                       Collection<ClassId> generatedFiles,
                       Collection<ClassId> usedSourceFiles,
                       Collection<URI> inputFiles,
                       Collection<URI> outputFiles) {
            super(fileManager);
            this.generatedFiles = generatedFiles;
            this.usedSourceFiles = usedSourceFiles;
            this.inputFiles = inputFiles;
            this.outputFiles = outputFiles;
        }

        @Override
        public String inferBinaryName(Location location,
                                      JavaFileObject file) {
            if (file instanceof ReadHook) {
                return super.inferBinaryName(location,
                                             ((ReadHook) file).base());
            } else {
                return super.inferBinaryName(location, file);
            }
        }

        @Override
        public FileObject getFileForInput(Location location,
                                          String packageName,
                                          String relativeName)
            throws IOException {
            FileObject result =
                super.getFileForInput(location, packageName, relativeName);
            if (result != null && location == StandardLocation.SOURCE_PATH)
                inputFiles.add(result.toUri());
            return result;
        }

        @Override
        public FileObject
            getFileForOutput(Location location, String packageName,
                             String relativeName, FileObject sibling)
                throws IOException {
            FileObject result = super.getFileForOutput(location, packageName,
                                                       relativeName, sibling);
            if (result != null && location == StandardLocation.CLASS_OUTPUT)
                outputFiles.add(result.toUri());
            return result;
        }

        @Override
        public JavaFileObject getJavaFileForInput(Location location,
                                                  String className, Kind kind)
            throws IOException {
            JavaFileObject result =
                super.getJavaFileForInput(location, className, kind);
            if (result != null) {
                ClassId clid = getClassId(location, result);
                if (kind == Kind.SOURCE) usedSourceFiles.add(clid);
            }
            return result;
        }

        private ClassId getClassId(Location location, JavaFileObject item) {
            assert item != null;
            return ClassId
                .forName(inferBinaryName(location, item).replace('.', '/'));
        }

        @Override
        public Iterable<JavaFileObject> list(Location location,
                                             String packageName,
                                             Set<Kind> kinds, boolean recurse)
            throws IOException {
            Iterable<JavaFileObject> result =
                super.list(location, packageName, kinds, recurse);
            if (location == StandardLocation.SOURCE_PATH) {
                List<JavaFileObject> altered = new ArrayList<>();
                for (JavaFileObject item : result) {
                    if (item.getKind() == Kind.SOURCE) {
                        final ClassId clid = getClassId(location, item);
                        JavaFileObject alt =
                            new ReadHook(item, clid, usedSourceFiles);
                        altered.add(alt);
                    } else {
                        altered.add(item);
                    }
                }
                return altered;
            }
            return result;
        }

        @Override
        public JavaFileObject
            getJavaFileForOutput(Location location, String className,
                                 Kind kind, FileObject sibling)
                throws IOException {
            JavaFileObject result =
                super.getJavaFileForOutput(location, className, kind,
                                           sibling);
            if (kind == Kind.CLASS
                && location == StandardLocation.CLASS_OUTPUT)
                generatedFiles
                    .add(ClassId.forName(className.replace('.', '/')));
            return result;
        }
    }

    private static class ReadHook
        extends ForwardingJavaFileObject<JavaFileObject> {
        private final ClassId clid;
        private final Collection<? super ClassId> into;

        public ReadHook(JavaFileObject base, ClassId clid,
                        Collection<? super ClassId> into) {
            super(base);
            this.clid = clid;
            this.into = into;
        }

        private JavaFileObject base() {
            return fileObject;
        }

        private void record() {
            into.add(clid);
        }

        @Override
        public InputStream openInputStream() throws IOException {
            record();
            return super.openInputStream();
        }

        @Override
        public CharSequence getCharContent(boolean ignoreEncodingErrors)
            throws IOException {
            record();
            return super.getCharContent(ignoreEncodingErrors);
        }

        @Override
        public Reader openReader(boolean ignoreEncodingErrors)
            throws IOException {
            record();
            return super.openReader(ignoreEncodingErrors);
        }
    }
}
