# NAME

Mail::SpamAssassin::Plugin::QRCode

# DESCRIPTION

SpamAssassin plugin to extract URI's from QR codes embedded in image attachments. URI's are added to the
URI detail list with the type 'qrcode'. You can use the 'uri\_detail' rule to match
on these URI's.

# SYNOPSIS

    loadplugin Mail::SpamAssassin::Plugin::QRCode

    qrcode_min_width 100
    qrcode_max_width 0
    qrcode_min_height 100
    qrcode_max_height 0

    uri_detail      HAS_QRCODE_URI   type =~ /^qrcode$/
    describe        HAS_QRCODE_URI   Message contains a URI embedded in a QR code

# CONFIGURATION

- qrcode\_min\_width (default: 100)

    Minimum width of the image in pixels. Images smaller than this will be skipped.

- qrcode\_max\_width (default: 0 (no limit))

    Maximum width of the image in pixels. Images larger than this will be skipped.

- qrcode\_min\_height (default: 100)

    Minimum height of the image in pixels. Images smaller than this will be skipped.

- qrcode\_max\_height (default: 0 (no limit))

    Maximum height of the image in pixels. Images larger than this will be skipped.

# REQUIREMENTS

This plugin requires the following Perl modules:

- Mail::SpamAssassin (version 4.0.1 or later)
- Barcode::ZBar
- Image::Magick

# AUTHORS

Kent Oyer <kent@mxguardian.net>

Portions borrowed from [Email::Barcode::Decode](https://metacpan.org/pod/Email::Barcode::Decode) by Jozef Kutej

# COPYRIGHT AND LICENSE

Copyright (C) 2024 MXGuardian LLC

This is free software; you can redistribute it and/or modify it under
the terms of the Apache License 2.0. See the LICENSE file included
with this distribution for more information.

This plugin is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
