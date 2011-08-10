# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More;

BEGIN { use_ok( 'WWW::YouTube::Download::Channel' ); }

my $yt = WWW::YouTube::Download::Channel->new ();
isa_ok ($yt, 'WWW::YouTube::Download::Channel');
$yt->debug(1);
$yt->apply_regex_filter('translate beat box');
$yt->leech_channel('google');
$yt->download_all;

sub is_file_downloaded {
    return 1 if ( -e 'Google-Demo-Slam-Translate-Beat-Box' );
} 
is( 1, is_file_downloaded , 'video downloaded..' );

if ( -e 'Google-Demo-Slam-Translate-Beat-Box' ) {
    unlink 'Google-Demo-Slam-Translate-Beat-Box'; # clean up
} 

done_testing();
