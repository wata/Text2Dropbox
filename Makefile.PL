use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Text2Dropbox',
    AUTHOR        => 'Wataru Nagasawa <nagasawa@junkapp.com>',
    VERSION_FROM  => 'app.psgi',
    PREREQ_PM     => {
        'Amon2'                           => '2.46',
        'Text::Xslate'                    => '1.1005',
        'Text::Xslate::Bridge::TT2Like'   => '0.00008',
        'Plack::Middleware::ReverseProxy' => '0.09',
        'Time::Piece'                     => '1.20',
        'Text::Markdown'                  => 0,
        'Text::Xatena'                    => 0,
        'Net::Dropbox::API'               => 0,
        'LWP::Protocol::https'            => 0,
    },
    MIN_PERL_VERSION => '5.008001',
    (-d 'xt' and $ENV{AUTOMATED_TESTING} || $ENV{RELEASE_TESTING}) ? (
        test => {
            TESTS => 't/*.t xt/*.t',
        },
    ) : (),
);
