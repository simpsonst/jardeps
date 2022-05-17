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

enum Visibility {
    PRIVATE(false, false),
    PACKAGE_PRIVATE(false, true),
    PROTECTED(true, true),
    PUBLIC(true, true);

    Visibility(boolean isPublic, boolean isVisible) {
        this.isPublic = isPublic;
        this.isVisible = isVisible;
    }

    private final boolean isPublic, isVisible;

    public boolean isPublic() {
        return isPublic;
    }

    public boolean isVisible() {
        return isVisible;
    }

    public Visibility min(Visibility other) {
        if (other.ordinal() < ordinal()) return other;
        return this;
    }

    public static Visibility forFlags(int flags) {
        if ((flags & Constants.ACC_PROTECTED) != 0) return PROTECTED;
        if ((flags & Constants.ACC_PUBLIC) != 0) return PUBLIC;
        if ((flags & Constants.ACC_PRIVATE) != 0) return PRIVATE;
        return PACKAGE_PRIVATE;
    }
}
