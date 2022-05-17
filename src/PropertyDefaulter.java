
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

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Iterator;
import java.util.Properties;

public class PropertyDefaulter {
    public static void main(String[] args) throws IOException {
        for (int i = 0; i < args.length; i += 3) {
            System.err.printf("  %s%n", args[i]);
            Properties specifics = new Properties();
            Properties generics = new Properties();

            try (InputStream in = new FileInputStream(args[i + 1])) {
                specifics.load(in);
            }

            try (InputStream in = new FileInputStream(args[i + 2])) {
                generics.load(in);
            }

            for (Iterator<Object> iter = specifics.keySet().iterator(); iter
                .hasNext();) {
                String key = iter.next().toString();
                if (generics.containsKey(key)) continue;
                generics.setProperty(key, specifics.getProperty(key));
                iter.remove();
            }

            try (OutputStream out = new FileOutputStream(args[i + 1])) {
                specifics.store(out, "Yikes");
            }

            try (OutputStream out = new FileOutputStream(args[i + 2])) {
                generics.store(out, "Splimmy");
            }
        }
    }
}
