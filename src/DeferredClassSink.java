
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

import java.util.ArrayList;
import java.util.List;

/**
 * 
 */
@Deprecated
class DeferredClassSink implements ClassSink {
    private interface Target {
        void apply(ClassSink sink);
    }

    public void apply(ClassSink sink) {
        for (DeferredClassSink.Target t : actions)
            t.apply(sink);
    }

    private final List<DeferredClassSink.Target> actions = new ArrayList<>();

    @Override
    public void submit(final ClassId clid) {
        actions.add(new Target() {
            @Override
            public void apply(ClassSink sink) {
                sink.submit(clid);
            }
        });
    }

    @Override
    public void submitMethodSignature(final String text) {
        actions.add(new Target() {
            @Override
            public void apply(ClassSink sink) {
                sink.submitMethodSignature(text);
            }
        });
    }

    @Override
    public void submitFieldSignature(final String text) {
        actions.add(new Target() {
            @Override
            public void apply(ClassSink sink) {
                sink.submitFieldSignature(text);
            }
        });
    }

    @Override
    public void submitClassSignature(final String text) {
        actions.add(new Target() {
            @Override
            public void apply(ClassSink sink) {
                sink.submitClassSignature(text);
            }
        });
    }

    @Override
    public void submitTypeSignature(final String text) {
        actions.add(new Target() {
            @Override
            public void apply(ClassSink sink) {
                sink.submitTypeSignature(text);
            }
        });
    }
}
