#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib 'lib';
use Test::More;
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
        debug              => '0',
        post_config_text        => <<'EOF'
            loadplugin Mail::SpamAssassin::Plugin::QRCode

            qrcode_scan_pdf 0

            uri     QRCODE_URI     /p1001\.syd1\.digitaloceanspaces\.com/

EOF
            ,
    }
);

my @files = (
    {
        'name'       => 't/data/msg1.eml',
        'hits'       => {
            'QRCODE_URI' => 1,
        },
    },
);

plan tests => scalar @files;

# test each file
foreach my $file (@files) {
    print "Testing $file->{name}\n";
    my $path = $file->{name};
    open my $fh, '<', $path or die "Can't open $path: $!";
    my $msg = $spamassassin->parse($fh);
    my $pms = $spamassassin->check($msg);
    close $fh;

    my $hits = $pms->get_names_of_tests_hit_with_scores_hash();
    my $pattern_hits = $pms->{pattern_hits};

    # remove all but QRCODE tests
    foreach my $test (keys %$hits) {
        delete $hits->{$test} unless $test =~ /QRCODE/;
    }
    is_deeply($hits, $file->{hits}, $file->{name});
}

