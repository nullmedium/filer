#!/bin/sh

svn log --xml --verbose http://svn.foo-projects.org/svn/filer/trunk/ | xsltproc svn2cl.xsl - > ChangeLog

