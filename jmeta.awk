# This simply reads in a list of root classes.
{
    unprocessed[$0] = 1;
}


END {
    # We have a list of classes.

    delete api;
    api_index = 0;
    ppi_index = 0;

    while (length(unprocessed) > 0) {
	# Build a command.
#	printf "\nParsing new set of classes:\n";
	command = JAVAP " -verbose -private -c -s -classpath " JARDEPS_CLASSDIR "/" jar;
	for (todo_class in unprocessed) {
	    command = command " " gensub("\\$", "\\\\$", "g", todo_class);
	    known[todo_class] = 1;
#	    printf "  %s\n", todo_class;
	}
	command = command " | " AWK " -f " JARDEPS_HOME "/jmeta-inner.awk";
	delete unprocessed;

#	printf "Command: %s\n", command;
	while (command | getline) {
	    if ($0 == "--")
		break;
	    if ($0 in known)
		continue;
	    if (exists("" JARDEPS_CLASSDIR "/" jar "/" $0 ".class"))
		unprocessed[$0] = 1;
	}
	while (command | getline) {
	    if ($0 == "--")
		break;
	    api[api_index++] = $0;
	}
	while (command | getline)
	    ppi[ppi_index++] = $0;

	close(command);
    }

    api_test_file = "" JARDEPS_TMPDIR "/" jar ".api-test";
    ppi_test_file = "" JARDEPS_TMPDIR "/" jar ".ppi-test";
    dep_file = "" JARDEPS_TMPDIR "/" jar ".mk";
    list_file = "" JARDEPS_TMPDIR "/" jar ".list";

    # Generate the API test file.
    api_index = asort(api);
    printf "" > api_test_file;
    for (i = 1; i <= api_index; i++)
	print api[i] > api_test_file;
    close(api_test_file);

    # Generate the PPI test file.
    ppi_index = asort(ppi);
    printf "" > ppi_test_file;
    for (i = 1; i <= ppi_index; i++)
	print ppi[i] > ppi_test_file;
    close(ppi_test_file);

    # Generate the internal dependencies triggering rebuild of this
    # jar.
    printf "$(JARDEPS_TMPDIR)/%s.compiled $(JARDEPS_OUTDIR)/%s-src.zip:", jar, jar > dep_file;
    for (known_class in known) {
	if (index(known_class, "$"))
	    continue;
	printf " \\\n  $(JARDEPS_SRCDIR)/%s/%s.java", jar, known_class > dep_file;
    }
    printf "\n" > dep_file;
    for (known_class in known) {
	if (index(known_class, "$"))
	    continue;
	printf "$(JARDEPS_SRCDIR)/%s/%s.java:\n", jar, known_class > dep_file;
    }
    printf "\n" > dep_file;
    close(dep_file);

    # Generate the class list.
    for (known_class in known)
	print known_class ".class" > list_file;
    close(list_file);
}

function exists(file,

		dummy, ret)
{
    file = gensub("\\", "\\\\", "g", file);
    file = gensub("\\$", "\\$", "g", file);
    ret=0;
    if ( (getline dummy < file) >=0 )
    {
        # file exists (possibly empty) and can be read
        ret = 1;
        close(file);
    }
    return ret;
}
