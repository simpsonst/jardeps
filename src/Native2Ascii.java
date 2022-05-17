
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

import java.io.IOException;
import java.io.Reader;
import java.io.InputStreamReader;
import java.io.Writer;
import java.io.OutputStreamWriter;
import java.io.InputStream;
import java.io.FileInputStream;
import java.io.OutputStream;
import java.io.FileOutputStream;
import java.util.Properties;
import java.nio.charset.Charset;

public class Native2Ascii {
    private static InputStream openIn(String name) throws IOException {
        if (name == null) return System.in;
        return new FileInputStream(name);
    }

    private static OutputStream openOut(String name) throws IOException {
        if (name == null) return System.out;
        return new FileOutputStream(name);
    }

    public static void main(String[] args) throws Exception {
        boolean reverse = false;
        Charset enc = Charset.defaultCharset();
        String progName = null;
        String inputName = null;
        String outputName = null;

        for (int i = 0; i < args.length; i++) {
            if ("-encoding".equals(args[i])) {
                enc = Charset.forName(args[++i]);
            } else if ("-reverse".equals(args[i])) {
                reverse = true;
            } else if (progName == null) {
                progName = args[i];
            } else if (inputName == null) {
                inputName = args[i];
            } else if (outputName == null) {
                outputName = args[i];
            } else {
                System.err.printf("%s: too many arguments: %s%n", progName,
                                  args[i]);
                System.exit(1);
            }
        }

        final Properties props = new Properties();

        if (reverse) {
            try (InputStream in = openIn(inputName)) {
                props.load(in);
            }
            try (Writer out =
                new OutputStreamWriter(openOut(outputName), enc)) {
                props.store(out, COMMENT);
            }
        } else {
            try (Reader in = new InputStreamReader(openIn(inputName), enc)) {
                props.load(in);
            }
            try (OutputStream out = openOut(outputName)) {
                props.store(out, COMMENT);
            }
        }
    }

    private static final String COMMENT =
        "Created by replacement native2ascii in Jardeps";
}
