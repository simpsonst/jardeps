match($0, /^\s*Parsing ([^/].*)$/, ary) {
    CAND[ary[1]];
}

END {
    for (cand in CAND) {
	file = DIR "/" cand;
	if (system("test -r " file))
	    delete CAND[cand];
    }
    for (cand in CAND) {
	printf "$(JARDEPS_TMPDIR)/tree-%s.compiled: $(JARDEPS_IDLDIR)/%s\n",
	    TARGET, cand;
	printf "$(JARDEPS_IDLDIR)/%s:\n", cand;
    }
}
