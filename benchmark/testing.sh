#!/bin/bash

source ~/.bashrc

for VERSION in 1.8.5 1.8.6 1.8.7 1.9.1 1.9.2 'jruby 1.4.0'; do
	rvm $VERSION
	echo $(ruby -v)
	RUBYOPT=-rubygems rake test
done
