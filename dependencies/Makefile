# Makefile for installing CodeRunner dependencies
# Written by Edmund Highcock Oct 2012
# edmundhighcock@sourceforge.net
#

MY_MAKEFLAGS?=
MY_CONFFLAGS=LDFLAGS=-L${PREFIX}/lib CFLAGS=-I${PREFIX}/include

# Packages
NETCDF="netcdf-4.2.1.1"
GSL="gsl-1.16"
HDF5="hdf5-1.8.9"
YAML="yaml-0.1.4"
READLINE="readline-6.2"
NCURSES="ncurses-5.9"
RUBY="ruby-2.3.0"

help:
	@echo
	@echo
	@echo "----------------------------------------------------------------"
	@echo "A Makefile for installing the dependencies of CodeRunner."
	@echo "If you are not sure which are already on your system then"
	@echo "type:"
	@echo "   make hd all rb PREFIX=<yourprefix>"
	@echo "where your prefix is the folder where you want to install it."
	@echo
	@echo "If you want to install only certain ones then choose from "
	@echo "-> gsl(gl), hdf5(hd), netcdf(nc), yaml(ym), readline(rl), ncurses(nu)"
	@echo "-> ruby(rb) [mandatory, must be done after ym and rl]"
	@echo
	@echo "e.g."
	@echo "   make gl nc ym  PREFIX=<yourprefix>"
	@echo "   make rb  PREFIX=<yourprefix>"
	@echo
	@echo "Notes:"
	@echo "1. If you take the second option and use system libraries"
	@echo "   you may run into a whole host of compatibility issues."
	@echo "   If you are not confident with what you are doing we "
	@echo "   recommend that you install everything again from here."
	@echo "2. Why doesn't the makefile resolve the depencies of ruby"
	@echo "   i.e. readline, ncurses and yaml? Because we don't want to have to"
	@echo "  start with readline and yaml every time the ruby installation"
	@echo "  is unexpectedly interrupted."
	@echo "----------------------------------------------------------------"

.default_goal: help

all: netcdf gsl readline yaml ncurses

gl: gsl

gsl:
	tar -xzf ${GSL}.tar.gz
	cd ${GSL}; ./configure --prefix=${PREFIX} && make ${MY_MAKEFLAGS} && make install ${MY_MAKEFLAGS}

hd: hdf5

hdf5:
	tar -xzf ${HDF5}.tar.gz
	cd ${HDF5}; ./configure --prefix=${PREFIX} && make ${MY_MAKEFLAGS} && make install ${MY_MAKEFLAGS}

nc: netcdf

netcdf:
	tar -xzf ${NETCDF}.tar.gz
	cd ${NETCDF}; ./configure ${MY_CONFFLAGS} --prefix=${PREFIX} --enable-shared --enable-netcdf4 && make ${MY_MAKEFLAGS} && make install ${MY_MAKEFLAGS}

ym: yaml

yaml:
	tar -xzf ${YAML}.tar.gz
	cd ${YAML}; ./configure --prefix=${PREFIX} && make ${MY_MAKEFLAGS} && make install ${MY_MAKEFLAGS}

rl: readline

readline:
	tar -xzf ${READLINE}.tar.gz
	cd ${READLINE}; ./configure --prefix=${PREFIX} &&  make ${MY_MAKEFLAGS}  && make install ${MY_MAKEFLAGS}

nu: ncurses

ncurses:
	tar -xzf ${NCURSES}.tar.gz
	cd ${NCURSES};  ./configure --prefix=${PREFIX} --with-shared &&  make ${MY_MAKEFLAGS}  && make install ${MY_MAKEFLAGS}

rb: ruby

ruby:
	tar -xzf ${RUBY}.tar.gz
	cd ${RUBY};  ./configure --prefix=${PREFIX} ${MY_CONFFLAGS} && make ${MY_MAKEFLAGS} && make install ${MY_MAKEFLAGS}
	cd ${RUBY}/ext/readline; ruby extconf.rb ; make && make install
	cd ${RUBY}/ext/psych/; ruby extconf.rb ; make && make install

ruby_ext:
	cd ${RUBY}/ext/readline; ruby extconf.rb ; make && make install
	cd ${RUBY}/ext/psych/; ruby extconf.rb ; make && make install

clean:
	rm -rf ${RUBY} ${RUBY} ${NETCDF} ${YAML} ${READLINE} ${GSL}
	rm -rf ${NCURSES} ${HDF5}
