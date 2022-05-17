/*
 * Copyright (c) 2007-16,2018-19,2021-22, Lancaster University
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

package uk.ac.lancs.scc.jardeps;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Identifies a class which can be run as an application. The class will
 * then automatically be set as the <samp>Main-Class</samp> of the jar
 * it finds itself in.
 * 
 * @author simpsons
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.SOURCE)
public @interface Application {
    /**
     * Determine whether this class should be the main class of its
     * containing jar.
     * 
     * @return {@code true} if this class should be the main class;
     * {@code false} otherwise
     */
    boolean value() default true;
}
