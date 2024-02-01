# <@LICENSE>
# Licensed under the Apache License 2.0. You may not use this file except in
# compliance with the License.  You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# </@LICENSE>

=head1 NAME

Mail::SpamAssassin::Plugin::QRCode

=head1 DESCRIPTION

SpamAssassin plugin to extract URI's from QR codes embedded in image attachments. URI's are added to the
URI detail list with the type 'qrcode'. You can use the 'uri_detail' rule to match
on these URI's.

=head1 SYNOPSIS

  loadplugin Mail::SpamAssassin::Plugin::QRCode

  ifplugin Mail::SpamAssassin::Plugin::QRCode
    qr_code_min_width     100
    qr_code_max_width     0
    qr_code_min_height    100
    qr_code_max_height    0
    qr_code_scan_pdf      0
  endif

  uri_detail      HAS_QRCODE_URI   type =~ /^qrcode$/
  describe        HAS_QRCODE_URI   Message contains a URI embedded in a QR code

=head1 CONFIGURATION

=over

=item qrcode_min_width (default: 100)

Minimum width of the image in pixels. Images smaller than this will be skipped.

=item qrcode_max_width (default: 0 (no limit))

Maximum width of the image in pixels. Images larger than this will be skipped.

=item qrcode_min_height (default: 100)

Minimum height of the image in pixels. Images smaller than this will be skipped.

=item qrcode_max_height (default: 0 (no limit))

Maximum height of the image in pixels. Images larger than this will be skipped.

=item qrcode_scan_pdf (default: 0)

Scan PDF attachments for QR codes. If you enable this, make sure you have Ghostscript 9.24 or later installed
because of a L<security vulnerability|https://www.kb.cert.org/vuls/id/332928/> in earlier versions. Also, you
need to enable the policy in ImageMagick's policy.xml file to allow reading PDF files. See the
L<documentation|https://imagemagick.org/script/security-policy.php> for details.

=back

=head1 REQUIREMENTS

This plugin requires the following Perl modules:

=over

=item Mail::SpamAssassin (version 4.0.1 or later)

=item Barcode::ZBar

=item Image::Magick

=back

=head1 AUTHORS

Kent Oyer <kent@mxguardian.net>

Portions borrowed from L<Email::Barcode::Decode|https://metacpan.org/pod/Email::Barcode::Decode> by Jozef Kutej

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 MXGuardian LLC

This is free software; you can redistribute it and/or modify it under
the terms of the Apache License 2.0. See the LICENSE file included
with this distribution for more information.

This plugin is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
package Mail::SpamAssassin::Plugin::QRCode;
use strict;
use warnings FATAL => 'all';

use Barcode::ZBar;
use Image::Magick;

use Mail::SpamAssassin::Plugin;
use Mail::SpamAssassin::Logger ();

our @ISA = qw(Mail::SpamAssassin::Plugin);
our $VERSION = 0.03;

sub dbg { Mail::SpamAssassin::Logger::dbg ("QRCode: @_"); }
sub info { Mail::SpamAssassin::Logger::info ("QRCode: @_"); }
sub warning { warn("QRCode: $_[0]"); }

sub new {
    my $class = shift;
    my $mailsa = shift;

    $class = ref($class) || $class;
    my $self = $class->SUPER::new($mailsa);
    bless($self, $class);

    # lower priority for add_uri_detail_list to work
    $self->register_method_priority ("parsed_metadata", -1);

    # set config
    $self->set_config($mailsa->{conf});

    # initialize zbar
    $self->{zbar} = Barcode::ZBar::ImageScanner->new();

    return $self;
}

sub set_config {
    my ($self, $conf) = @_;
    my @cmds;

    push(@cmds, {
        setting => 'qrcode_min_width',
        default => 100,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC,
    },{
        setting => 'qrcode_max_width',
        default => 0,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC,
    },{
        setting => 'qrcode_min_height',
        default => 100,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC,
    },{
        setting => 'qrcode_max_height',
        default => 0,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC,
    },{
        setting => 'qrcode_scan_pdf',
        default => 0,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_BOOL,
    });

    $conf->{parser}->register_commands(\@cmds);
}

sub finish_parsing_start {
    my ($self, $opts) = @_;
    my $conf = $opts->{conf};

    if ($conf->{qrcode_scan_pdf}) {
        $conf->{qrcode_scan_pdf} = 0 unless $self->check_pdf_support();
    }

}

sub check_pdf_support {

    # Make sure ImageMagick is configured to read PDF files
    my $image = Image::Magick->new();
    my $error = $image->BlobToImage(<<'END');
%PDF-1.0
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj 3 0 obj<</Type/Page/MediaBox[0 0 3 3]>>endobj
xref
0 4
0000000000 65535 f
0000000009 00000 n
0000000052 00000 n
0000000101 00000 n
trailer<</Size 4/Root 1 0 R>>
startxref
147
%EOF
END
    if ($error) {
        if ( $error =~ /policy/ ) {
            warning("ImageMagick is not configured to read PDF files. Please enable the policy in ImageMagick's policy.xml file to allow reading PDF files. See the documentation for details.\n");
            return 0;
        } else {
            die $error;
        }
    }

    return 1;
}

sub parsed_metadata {
    my ($self, $opts) = @_;

    #@type Mail::SpamAssassin::PerMsgStatus
    my $pms = $opts->{permsgstatus};
    #@type Mail::SpamAssassin::Conf
    my $conf = $pms->{conf};
    #@type Mail::SpamAssassin::Message
    my $msg = $pms->{msg};
    #@type Mail::SpamAssassin::Message::Node
    my $p;

    foreach $p ($msg->find_parts(qr/./, 1)) {
        my $mime_type = $p->effective_type();
        if ($mime_type =~ m@^image/(.*)@i || $mime_type =~ m@^application/(pdf)@i) {
            my $type = $1;
            next if $type eq 'pdf' && !$conf->{qrcode_scan_pdf};
            my $name = $p->{'name'} || "unknown $mime_type part";
            dbg("found $type part: $name");
            my $raw = $p->decode();
            next unless $raw;

            # load image
            my $magick = Image::Magick->new();
            my $error = $magick->BlobToImage($raw);
            if ($error) {
                # corrupt or unsupported image format
                dbg("failed to decode $name: $error\n");
                next;
            }

            # get image size
            my ($w, $h) = $magick->Get("width", "height");
            unless ($w && $h) {
                # can happen if the image is corrupt or truncated
                dbg("failed to decode $name: width or height not defined\n");
                next;
            }
            dbg("image size $w x $h");
            next if $conf->{qrcode_min_width} > 0 && $w < $conf->{qrcode_min_width};
            next if $conf->{qrcode_min_height} > 0 && $h < $conf->{qrcode_min_height};
            next if $conf->{qrcode_max_width} > 0 && $w > $conf->{qrcode_max_width};
            next if $conf->{qrcode_max_height} > 0 && $h > $conf->{qrcode_max_height};

            # get first frame from animated GIFs
            if ( $type eq 'gif' ) {
                # This should work, but it causes a segfault in ImageMagick 6.9.11-60
                # Need to investigate further
                # $magick = $magick->[0] if (scalar @{$magick} > 1);
            }

            # preprocessing
            $magick->Set(dither => 'False');
            $magick->Quantize(colors => 2);
            $magick->Quantize(colorspace => 'gray');
            $magick->ContrastStretch(levels => 0);
            $raw = $magick->ImageToBlob(magick => 'GRAY', depth => 8);

            # scan
            my $image = Barcode::ZBar::Image->new();
            $image->set_format("Y800");
            $image->set_size($w, $h);
            $image->set_data($raw);

            $self->{zbar}->scan_image($image);
            my @symbols = $image->get_symbols();
            dbg("found " . scalar(@symbols) . " symbols");
            foreach my $symbol (@symbols) {
                my $type = $symbol->get_type();
                my $data = $symbol->get_data();
                dbg("found $type: $data");
                if ( $data =~ m@^https?://@i ) {
                    $pms->add_uri_detail_list($data,{ qrcode => 1 },'QRCode');
                }
            }

        }
    }

}

1;