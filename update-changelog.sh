#!/bin/sh

svn log -v http://svn.foo-projects.org/svn/filer/trunk | perl svn2cl.pl > ChangeLog

