#!/bin/sh

find ./ -name "*.pl" -exec nc {} \;
find ./ -name "*.pm" -exec nc {} \;

