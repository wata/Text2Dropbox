use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Plack::Builder;
use Amon2::Lite;
use Encode 'encode_utf8';
use Text::Markdown 'markdown';
use Text::Xatena;
use Pod::Simple::XHTML;
use Net::Dropbox::API;
use File::Temp 'tempfile';
use Time::Piece;

# put your configuration here
sub config {
    +{
        'Dropbox' => {
            key          => "XXX your app key",
            secret       => "XXX your app secret",
            callback_url => "http://localhost:5000/callback",
            context      => "dropbox",
        }
    }
}

my $box = Net::Dropbox::API->new(config->{Dropbox});

my $converters = {
    markdown => sub {
        my $text = shift;
        return markdown($text);
    },
    xatena => sub {
        my $text = shift;
        return Text::Xatena->new->format($text);
    },
    pod => sub {
        my $text = shift;
        my $parser = Pod::Simple::XHTML->new;
        $parser->html_header('');
        $parser->html_footer('');
        $parser->output_string(\my $html);
        $parser->parse_string_document($text);
        return $html;
    },
};

get '/' => sub {
    my ($c) = @_;
    return $c->render('index.tt', {
        login => $box->login,
        user  => $c->session->get('user'),
    });
};

get '/callback' => sub {
    my ($c) = @_;
    return $c->redirect('/') unless $c->req->param('oauth_token');

    $box->auth;
    $c->session->set('user' => {
        access_token   => $box->access_token,
        access_secret  => $box->access_secret,
    });

    return $c->redirect('/');
};

get '/logout' => sub {
    my ($c) = @_;
    $c->session->expire('user');
    return $c->redirect('/');
};

post '/preview' => sub {
    my ($c) = @_;
    my $converter = $converters->{$c->req->param('format')};
    my $html = $converter ? $converter->($c->req->param('text')) : '';
    return $c->create_response(200, ['Content-Type' => 'text/plain'], [encode_utf8($html)]);
};

post '/upload' => sub {
    my ($c) = @_;

    my $user = $c->session->get('user');
    return $c->redirect('/') unless $user;

    my $text = $c->req->param('text');
    return $c->redirect('/') unless $text;

    my $now = localtime;
    my ($fh, $filename) = tempfile;
    print {$fh} $text;
    close $fh;

    $box->access_token($user->{access_token});
    $box->access_secret($user->{access_secret});
    $box->putfile($filename, 'Text2Dropbox', $now->ymd . '-' . $now->time('') . '.txt');

    return $c->redirect('/');
};

# for your security
__PACKAGE__->add_trigger(
    AFTER_DISPATCH => sub {
        my ( $c, $res ) = @_;
        $res->header( 'X-Content-Type-Options' => 'nosniff' );
    },
);

# load plugins
use HTTP::Session::Store::File;
__PACKAGE__->load_plugins(
    'Web::CSRFDefender',
    'Web::HTTPSession' => {
        state => 'Cookie',
        store => HTTP::Session::Store::File->new(
            dir => File::Spec->tmpdir(),
        )
    },
);

builder {
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/static/|/robot\.txt$|/favicon.ico$)},
        root => File::Spec->catdir(dirname(__FILE__));
    enable 'Plack::Middleware::ReverseProxy';

    __PACKAGE__->to_app();
};
