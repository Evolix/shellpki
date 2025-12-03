# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

### Security

## [25.12] 2025-12-03

### Added

* Add --no-crl to not renew the CRL when revoking a cert
* Add crl to only renew the CRL

### Changed

* Use ISO 8601 format for --end-date option
* Improve help

### Fixed

* Fix mode of shellpki script in README file when installing it

## [22.12.2] 2022-12-13

### Changed

* Defaults default_crl_days to 2 years instead of 1

### Fixed

* Fix ${CRL} and ${CA_DIR} rights so that CRL file can be read by openvpn

## [22.12.1] 2022-12-02

### Fixed

* cert-expirations.sh: check CARP state only when checking ca and certs expirations
* Fix path variables in cert-expirations.sh

## [22.12] 2022-12-01

### Added

* The key file can be read and written only by the owner

### Changed

* Use genpkey and pkey instead of genrsa and rsa
* Improved cert-expirations.sh for better readability of its ouput

### Fixed

* Create index.txt.attr file

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
