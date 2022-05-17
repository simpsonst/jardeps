BEGIN {
    in_members = 0;
    sig_len = -1;
    exc_line = -1;
    sig_line = 0;
    api_index = 0;
    ppi_index = 0;
}

/^(public |protected |private |)(static |)(abstract |final |)(class|interface)/ {
# A new class has been found.  We should start with fresh tables.
    delete Asciz;
    delete class;
    delete Method_class;
    delete Method_name;
    delete Method_type;
    delete InterfaceMethod_class;
    delete InterfaceMethod_name;
    delete InterfaceMethod_type;
    delete Field_class;
    delete Field_name;
    delete Field_type;
    delete NAT_name;
    delete NAT_type;
    delete String;

    sig_num = -1;
    plain_sig = "";
    member_level = -1;

# Record what we're dealing with.
    class_decl = $0;
    next_pos = 2;
    if ($1 == "public") {
	class_level = 0;
    } else if ($1 == "protected") {
	class_level = 1;
    } else if ($1 == "private") {
	class_level = 3;
    } else {
	class_level = 2;
	next_pos = 1;
    }

    if ($next_pos == "static") {
	next_pos++;
	is_static = 1;
    } else {
	is_static = 0;
    }

    if ($next_pos == "final") {
	next_pos++;
	is_final = 1;
	is_abstract = 0;
    } else if ($next_pos == "abstract") {
	next_pos++;
	is_final = 0;
	is_abstract = 1;
    } else {
	is_abstract = 0;
	is_final = 0;
    }

    is_interface = ($(next_pos) == "interface");
    class_name = gensub("\\.", "/", "g", $(next_pos + 1));
    is_inner = index(class_name, "$");
    if (match(class_name, "\\$[0-9]")) {
	# It's an anonymous class.
	class_level = 3;
    }
    source_name = is_inner ? substr(class_name, 1, is_inner - 1) : class_name;
    is_abstract = ($1 == "abstract" || $2 == "abstract");

    sep = lastindex(source_name, "/");
    package = substr(source_name, 1, sep);
    source_leafname = substr(source_name, sep + 1);

    top_level_classes[source_name] = 1;

    if (0) {
	printf "New %s: level %d;",				\
	    is_interface ? "interface" : "class", class_level > "/dev/stderr";
	if (is_static) printf " static" > "/dev/stderr";
	if (is_abstract) printf " abstract" > "/dev/stderr";
	if (is_final) printf " final" > "/dev/stderr";
	printf " %s\n", class_name > "/dev/stderr";
    }

    if (0) {
	printf "Package: %s\n", package > "/dev/stderr";
    }
}

/^  (public |protected |private |)(static |)(abstract |final |) #[0-9]+= #[0-9]+ of #[0-9]+;/ {
    # For InnerClass lines
}

/^const #[0-9]+ = Asciz\t/ {
    num = strtonum(substr($2, 2));
    val = "const #" num " = Asciz \t";
    val = tail(substr($0, length(val)), 1);
    Asciz[num] = val;
#    printf "Asciz[%d] = %s\n", num, val;
}

/^ *#[0-9]+ = Utf8 / {
    num = strtonum(substr($1, 2));
    val = substr($0,25);
    val = gensub("^ +", "", "", val);
    Asciz[num] = val;
#    printf "Utf8[%d] = %s\n", num, val > "/dev/stderr";
}

/^const #[0-9]+ = class\t/ {
    num = substr($2, 2);
    val = substr($5, 2);
    val = substr(val, 1, length(val) - 1);
    class[num] = val;
#    printf "class[%d] = %s\n", num, val;
}

/^ *#[0-9]+ = Class / {
    num = strtonum(substr($1, 2));
    val = strtonum(substr($4, 2));
    class[num] = val;
#    printf "Class[%d] = %s\n", num, val > "/dev/stderr";
}

/^const #[0-9]+ = Method\t/ {
    num = substr($2, 2);
    val = match($5, "#([0-9]+).#([0-9]+);", arr);
    Method_class[num] = arr[1];
    Method_name[num] = arr[2];
#    printf "Method[%d] = %s . %s\n", num, Method_class[num], Method_name[num];
}

/^ *#[0-9]+ = Methodref / {
    num = substr($1, 2);
    val = match($4, "#([0-9]+).#([0-9]+)", arr);
    Method_class[num] = arr[1];
    Method_name[num] = arr[2];
#    printf "Methodref[%d] = %s . %s\n", num, \
#	Method_class[num], Method_name[num] > "/dev/stderr";
}

/^const #[0-9]+ = InterfaceMethod\t/ {
    num = substr($2, 2);
    val = match($5, "#([0-9]+).#([0-9]+);", arr);
    InterfaceMethod_class[num] = arr[1];
    InterfaceMethod_name[num] = arr[2];
}

/^ *#[0-9]+ = InterfaceMethodref / {
    num = substr($1, 2);
    val = match($4, "#([0-9]+).#([0-9]+)", arr);
    InterfaceMethod_class[num] = arr[1];
    InterfaceMethod_name[num] = arr[2];
#    printf "InterfaceMethodref[%d] = %s . %s\n", num, \
#	InterfaceMethod_class[num], \
#	InterfaceMethod_name[num] > "/dev/stderr";
}

/^const #[0-9]+ = Field\t/ {
    num = substr($2, 2);
    val = match($5, "#([0-9]+).#([0-9]+);", arr);
    Field_class[num] = arr[1];
    Field_name[num] = arr[2];
}

/^ *#[0-9]+ = Fieldref / {
    num = substr($1, 2);
    val = match($4, "#([0-9]+).#([0-9]+)", arr);
    Field_class[num] = arr[1];
    Field_name[num] = arr[2];
#    printf "Fieldref[%d] = %s . %s\n", num, \
#	Field_class[num], \
#	Field_name[num] > "/dev/stderr";
}

/^const #[0-9]+ = NameAndType\t/ {
    num = substr($2, 2);
    val = match($5, "#([0-9]+).#([0-9]+);", arr);
    NAT_name[num] = arr[1];
    NAT_type[num] = arr[2];
}

/^ *#[0-9]+ = NameAndType / {
    num = substr($1, 2);
    val = match($4, "#([0-9]+).#([0-9]+)", arr);
    NAT_name[num] = arr[1];
    NAT_type[num] = arr[2];
#    printf "NameAndType[%d] = %s . %s\n", num, \
#	NAT_name[num], \
#	NAT_type[num] > "/dev/stderr";
}

/^}/ {
    close_member();

    in_members = 0;
    sig_line = 0;
}

/^$/ {
    sig_line = 1;
}

/^{/ {
    sig_line = 1;
    in_members = 1;


#    for (num in Asciz) {
#	printf "Asciz[%d] = %s\n", num, Asciz[num] > "/dev/stderr";
#    }

# Resolve constants.
    for (num in class) {
	class[num] = Asciz[class[num]];
#	printf "class[%d] = %s\n", num, class[num] > "/dev/stderr";
    }

    for (num in String) {
	String[num] = Asciz[String[num]];
#	printf "String[%d] = %s\n", num, String[num] > "/dev/stderr";
    }

    for (num in NAT_name) {
	NAT_name[num] = Asciz[NAT_name[num]];
	NAT_type[num] = Asciz[NAT_type[num]];
#	printf "NameAndType[%d] = %s : %s\n", num, \
#	    NAT_name[num], NAT_type[num] > "/dev/stderr";
    }

    for (num in Method_class) {
	Method_class[num] = class[Method_class[num]];
	Method_type[num] = NAT_type[Method_name[num]];
	Method_name[num] = NAT_name[Method_name[num]];
#	printf "Method[%d] = %s . %s : %s\n", num, \
#	    Method_class[num], Method_name[num], Method_type[num] > "/dev/stderr";
    }

    for (num in InterfaceMethod_class) {
	InterfaceMethod_class[num] = class[InterfaceMethod_class[num]];
	InterfaceMethod_type[num] = NAT_type[InterfaceMethod_name[num]];
	InterfaceMethod_name[num] = NAT_name[InterfaceMethod_name[num]];
#	printf "InterfaceMethod[%d] = %s . %s : %s\n", num, \
#	    InterfaceMethod_class[num], InterfaceMethod_name[num], \
#	    InterfaceMethod_type[num] > "/dev/stderr";
    }

    for (num in Field_class) {
	Field_class[num] = class[Field_class[num]];
	Field_type[num] = NAT_type[Field_name[num]];
	Field_name[num] = NAT_name[Field_name[num]];
#	printf "Field[%d] = %s . %s : %s\n", num, \
#	    Field_class[num], Field_name[num], Field_type[num] > "/dev/stderr";
    }

    close_class_header();
}

/^ +Exceptions:$/ {
    exc_line = 0;
}

{
    if (sig_line) {
	if ($0 == "") next;
	if ($0 == "{") next;
	sig_line = 0;

	member_decl = $0;

	# Remove leading space.
	member_decl = gensub("^ +", "", "", member_decl);

	if (member_decl == "Exceptions:") next;

	if (!in_members)
	    next;

	close_member();

	constant_value = "";

	# Remove private keywords.
	member_decl = gensub(" synchronized ", " ", "", member_decl);
	member_decl = gensub("^synchronized ", "", "", member_decl);

	if ($1 == "private") {
	    member_level = 3;
	} else if ($1 == "public") {
	    member_level = 0;
	} else if ($1 == "protected") {
	    member_level = 1;
	} else {
	    member_level = 2;
	}
	if (index($0, "{}")) {
	    # It's an initializer.
	    member_level = -1;
	} else if (match($0, "\\$[0-9]")) {
	    # It's an access method for a nested class.
	    member_level = -1;
	}
#	print member_level " " member_decl > "/dev/stderr";
	next;
    }

    if (sig_len >= 0) {
	sig_num = 0;
	for (i = 1; i <= NF; i++) {
	    sig_num *= 256;
	    sig_num += and(strtonum("0x" $i), 255);
	}
	sig_len = -1;
	next;
    }

    if (exc_line >= 0) {
	exceptions = $0;
	exc_line = -1;
    }
}

/^  Signature: / {
    if ($2 == "length") {
	sig_len = strtonum($4);
	next;
    }
    plain_sig = substr($0, 14);
}

/^    Signature: / {
    if ($2 == "length") {
	sig_len = strtonum($4);
#	printf "sig_len=%s\n", sig_len > "/dev/stderr";
	next;
    }
    plain_sig = $2;
#    printf "plain_sig=%s\n", plain_sig > "/dev/stderr";
    sig_num = -1;
}

/^    Signature: #[0-9]+/ {
    plain_sig = Asciz[strtonum(substr($2, 2))];
    sig_num = -1;
#    printf "plain_sig=%s\n", plain_sig > "/dev/stderr";
}

/^[^ 	{}]/ {
}

/^ +Constant value:/ {
    constant_value = substr($0, 19);
}

function tail(s, n) {
    return substr(s, 1, length(s) - n);
}

function close_member() {
    write_member_signature();
    member_level = -1;
    plain_sig = "";
    sig_num = -1;
    exceptions = "";
}

function write_member_signature() {
    if (member_level < 0)
	return;
    used_sig = sig_num < 0 ? plain_sig : Asciz[sig_num];
    get_deps_from_membersig(used_sig);
    applied_level = class_level > member_level ? class_level : member_level;
    line = class_name ": " member_decl " " used_sig " " constant_value;
    if (applied_level == 2)
	ppi[ppi_index++] = line;
    else if (applied_level < 2)
	api[api_index++] = line;
}

function close_class_header() {
    write_class_signature();
}

function write_class_signature() {
    for (num in class)
	add_dep(class[num]);
    used_sig = sig_num < 0 ? plain_sig : Asciz[sig_num];
    get_deps_from_classsig(used_sig);
    line = class_name ": " class_decl " " used_sig;
    if (class_level == 2)
	ppi[ppi_index++] = line;
    else if (class_level < 2)
	api[api_index++] = line;
}

function get_deps_from_classsig(sig,

				old) {
#    printf "Classsig before: %s\n", sig > "/dev/stderr";
    sig = get_deps_from_typeparams(sig);
    do {
	old = sig;
	sig = get_deps_from_type(sig);
    } while (old != sig);
#    printf "Classsig after: %s\n", sig > "/dev/stderr";
}

function get_deps_from_membersig(sig) {
#    printf "Membersig before: %s\n", sig > "/dev/stderr";
    sig = get_deps_from_typeparams(sig);
    sig = get_deps_from_parameters(sig);
    sig = get_deps_from_type(sig);
#    printf "Membersig after: %s\n", sig > "/dev/stderr";
    return sig;
}

function get_deps_from_typeparams(sig,

				  old) {
    if (substr(sig, 1, 1) != "<")
	return sig;
#    printf "Typeparams before: %s\n", sig > "/dev/stderr";
    sig = substr(sig, 2);
    do {
	old = sig;
	sig = get_deps_from_typeparam(sig);
    } while (sig != old);
    if (substr(sig, 1, 1) != ">") {
	printf "Wanting typeparams end; got: %s\n", sig;
	exit 1;
    }
    sig = substr(sig, 2);
#    printf "Typeparams after: %s\n", sig > "/dev/stderr";
    return sig;
}

function get_deps_from_typeparam(sig,

				 end, old) {
#    printf "Typeparam before: %s\n", sig > "/dev/stderr";
    end = index(sig, ":");
    sig = substr(sig, end);
    do {
	old = sig;
	sig = get_deps_from_constr(sig);
    } while (sig != old);
#    printf "Typeparam after: %s\n", sig > "/dev/stderr";
    return sig;
}

function get_deps_from_constr(sig,

			      old) {
    if (substr(sig, 1, 1) != ":")
	return sig;
#    printf "Constr before: %s\n", sig > "/dev/stderr";
    do {
	sig = substr(sig, 2);
    } while (substr(sig, 1, 1) == ":");
    sig = get_deps_from_type(sig);
#    printf "Constr after: %s\n", sig > "/dev/stderr";
    return sig;
}

function get_deps_from_parameters(sig,

				  old) {
    if (substr(sig, 1, 1) != "(")
	return sig;
#    printf "Parameters before: %s\n", sig > "/dev/stderr";
    sig = substr(sig, 2);
    do {
	old = sig;
	sig = get_deps_from_type(sig);
    } while (sig != old);
    if (substr(sig, 1, 1) != ")") {
	printf "Wanting parameter end; got: %s\n", sig;
	exit 1;
    }
    sig = substr(sig, 2);
#    printf "Parameters after: %s\n", sig > "/dev/stderr";
    return sig;
}

function get_deps_from_typeargs(sig,

				old) {
    if (substr(sig, 1, 1) != "<")
	return sig;
#    printf "Typeargs before: %s\n", sig > "/dev/stderr";
    sig = substr(sig, 2);
    do {
	old = sig;
	sig = get_deps_from_type(sig);
    } while (sig != old);
    if (substr(sig, 1, 1) != ">") {
	printf "Wanting typearg end; got: %s\n", sig;
	exit 1;
    }
    sig = substr(sig, 2);
#    printf "Typeargs after: %s\n", sig > "/dev/stderr";
    return sig;
}

function get_deps_from_type(sig,

			    first, end, old) {
    old = sig;
    first = substr(sig, 1, 1);
    if (index("VZBCSIJDF*", first)) {
#	printf "Type before: %s\n", old > "/dev/stderr";
	sig = substr(sig, 2);
    } else if (index("[-+", first)) {
#	printf "Type before: %s\n", old > "/dev/stderr";
	sig = substr(sig, 2);
	sig = get_deps_from_type(sig);
    } else if (first == "T") {
#	printf "Type before: %s\n", old > "/dev/stderr";
	sig = substr(sig, 2);
	end = match(sig, "[<;]");
	sig = substr(sig, end);
	sig = get_deps_from_typeargs(sig);
	sig = substr(sig, 2);
    } else if (first == "L") {
#	printf "Type before: %s\n", old > "/dev/stderr";
	sig = substr(sig, 2);
	end = match(sig, "[<;]");
	add_dep(substr(sig, 1, end - 1));
	sig = substr(sig, end);
	sig = get_deps_from_typeargs(sig);
	sig = substr(sig, 2);
    }
#    if (old != sig) printf "Type after: %s\n", sig > "/dev/stderr";
    return sig;
}

			    


function lastindex(s, c,

		   n, done) {
    done = 0;
    while ((n = index(s, c)) > 0) {
	done += n;
	s = substr(s, n + 1);
    }
    return done;
}

function sort_api(target, source, middle, name) {
    close(source);
    system("sort < " source " > " middle);
    system("if cmp " target " " middle " > /dev/null 2>&1" \
	   " ; then printf \"No change for %s\n\" \"" name "\" ; else" \
	   " printf \"Changed %s\n\" \"" name \
	   "\" ; mv " middle " " target " ; fi");
}

END {
    for (dep_class in dep)
	print dep_class;
    print "--";

    for (i in api)
	print api[i];
    print "--";

    for (i in ppi)
	print ppi[i];
}

function add_dep(dep_name) {
    # Remove leading space.
    dep_name = gensub("^ +", "", "", dep_name);

#    printf "Adding: %s\n", dep_name > "/dev/stderr";
    dep[dep_name] = 1;
}
