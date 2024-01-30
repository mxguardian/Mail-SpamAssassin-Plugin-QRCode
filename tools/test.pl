#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib 'lib';
use Mail::SpamAssassin;

my $spamassassin = Mail::SpamAssassin->new(
    {
        dont_copy_prefs    => 1,
        local_tests_only   => 1,
        use_bayes          => 0,
        use_razor2         => 0,
        use_pyzor          => 0,
        use_dcc            => 0,
        use_auto_whitelist => 0,
        debug              => 'QRCode',
        pre_config_text    => 'loadplugin Mail::SpamAssassin::Plugin::QRCode'
    }
);

my $path = shift @ARGV;
open my $fh, '<', $path or die "Can't open $path: $!";
my $msg = $spamassassin->parse($fh);
my $pms = $spamassassin->check($msg);
close $fh;

for my $raw (keys %{ $pms->get_uri_detail_list() }) {
    print "$raw\n";
}
