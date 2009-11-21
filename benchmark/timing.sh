#!/bin/bash

source ~/.bashrc

for VERSION in 1.8.6 1.8.7 1.9.1 1.9.2; do
	rvm $VERSION
	echo $(ruby -v)
	ruby -Ilib bin/kramdown < benchmark/mdsyntax.text 2>&1 > /dev/null
	time ruby -Ilib bin/kramdown < benchmark/mdsyntax.text > /dev/null
done
