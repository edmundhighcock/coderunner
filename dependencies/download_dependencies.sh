#!/bin/bash

DIR="$PWD"

while [ $# -gt 0 ]
do
    case "$1" in
        -P) DIR="$2"; shift
    esac
    shift
done

wget -nc ftp://ftp.gnu.org/gnu/gsl/gsl-1.16.tar.gz -P $DIR
wget -nc https://www.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8.9/src/hdf5-1.8.9.tar.gz -P $DIR
wget -nc ftp://ftp.gnu.org/gnu/ncurses/ncurses-5.9.tar.gz -P $DIR
wget -nc ftp://ftp.unidata.ucar.edu/pub/netcdf/old/netcdf-4.2.1.1.tar.gz -P $DIR
wget -nc ftp://ftp.gnu.org/gnu/readline/readline-6.2.tar.gz -P $DIR
wget -nc http://pyyaml.org/download/libyaml/yaml-0.1.4.tar.gz -P $DIR
wget -nc https://cache.ruby-lang.org/pub/ruby/ruby-2.3.0.tar.gz -P $DIR

