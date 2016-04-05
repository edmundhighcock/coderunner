System dependencies
===================

CodeRunner requires the following system-level dependencies:

1. GSL
2. HDF5
3. ncurses
4. NetCDF
5. readline
6. Ruby
7. yaml

To install these, there are two option:

1. Install through a package manager (recommended).
2. Install using the from source.

In some cases, packages downloaded through the system package manager are too
old for some RubyGems. In that case follow the manual installation below.

Manual Installation
=================

1. Run `./download_dependencies.sh -P /path/to/download/dir`. Default
   location is in the dependencies directory.
2. To compile all the packages, run `make hd all rb PREFIX=/path/to/install/dir`.
3. If you only want to build one package see the makefile for the short name
   of the package. If you find any of these out of date, please open an
   issue of GitHub.
4. Finally, export these to the system PATH by adding the following to your
   `.bashrc`:

   `export PATH=/path/to/install/dir:$PATH`
