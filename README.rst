*************
pathup
*************

System path updator for Windows

===========
PLATFORMS
===========

Works on Windows 7, 10

==============
REQUIREMENTS
==============

- Ruby 1.9.3 or later
- Diff::LCS
- Win32API (since Ruby 3.0)

=========
SETUP
=========

::

  > gem install diff-lcs
  > gem install win32api

Just copy pathup.rb into your convenient directory.

=========
Usage
=========

::

  > ruby pathup.rb [options]


Without any options, show current system path and backup if changed.

-e     edit system_path.txt 
-u     update system path with system_path.txt

The -u option may require administrator privileges.


.. EOF
