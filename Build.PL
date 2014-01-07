use 5.008001;
use strict;
use warnings FATAL => 'all';
use Module::Build;

my $IS_WINDOWS = ($^O eq "MSWin32" or $^O eq "cygwin") ? 1 : 0;
my %SERIAL;
if ($IS_WINDOWS) {
    %SERIAL=('Win32::SerialPort' => 0);
} else {
    %SERIAL=('Device::SerialPort' => 0);
}

my $builder = Module::Build->new(
    module_name         => 'LedSign',
    license             => 'FreeBSD',
    dist_author         => q{Kerry Schwab <sales@brightledsigns.com>},
    dist_version_from   => 'lib/LedSign.pm',
    release_status      => 'stable',
    configure_requires => {
        'Module::Build' => 0,
    },
    test_requires  => {
        'Test::More' => 0,
        'Digest::MD5' => 0,
    },
    requires => {
        perl         => 5.008001,
        %SERIAL,
        'POSIX'      => 0,
        'Carp'       => 0
      
    },
    add_to_cleanup     => [ 'LedSign-*' ],
);
$builder->create_build_script();
