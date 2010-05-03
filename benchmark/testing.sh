#!/bin/bash

source ~/.bashrc

for VERSION in `rvm list strings`; do
	rvm $VERSION
	echo $(ruby -v)
	RUBYOPT=-rubygems rake test
done
