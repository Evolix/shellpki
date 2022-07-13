# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed

* Create index.txt.attr file

### Removed

### Security

## [22.04] 2022-04-14

### Added

* Create a changelog
* Add a version number and `version` command
* Accept a `password-file` command line option to read password from a file
* Accept `--days` and `--end-date` command line options
* CA key length is configurable (minimum 4096)
* Add `--non-interactive` command line option
* Add `--replace-existing` command line option
* Copy files if destination exists
* Generate the CRL file after initialization of the CA
* `cert-expirations.sh` script to print out certificates expiration dates

### Changed

* Rename internal function usage() to show_usage()
* Split show_usage() for each subcommand
* More readable variable names
* verify_ca_password() looks for a previously set password and verifies it
* Extract cert_end_date() function
* Extract is_user() and is_group() functions
* Extract ask_user_password() function
* Extract variables for files
* Use inline pass phrase arguments
* Create files with a human readable date instead of epoch
* Remove "set -e" and add many return code checks
* Prevent use of uninitialized variables

### Fixed

* Check on $USER was always true
