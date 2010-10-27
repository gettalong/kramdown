#!/bin/bash

source ~/.bashrc

for VERSION in `rvm list strings | sort`; do
	rvm $VERSION
	echo $(ruby -v)
	RUBYOPT=-rubygems rake test
done
