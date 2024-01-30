#!/usr/bin/sh
#
# Run tests
#
prove

#
# Generate the README.md file from the POD
#
pod2markdown lib/Mail/SpamAssassin/Plugin/QRCode.pm >README.md
