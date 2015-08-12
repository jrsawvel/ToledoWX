package Yo;

use strict;
use warnings;
use LWP::UserAgent;

my %URLS = (
    'all'         => 'http://api.justyo.co/yoall/',
    'user'        => 'http://api.justyo.co/yo/',
    'subscribers' => 'http://api.justyo.co/subscribers_count/'
);

sub new {
    my ($class, $api_token) = @_;
    my $self = ();
    $self->{api_token} = $api_token;
    $self->{link}      = undef;
    bless($self, $class);                 
    return $self;
}

sub set_link {
    my ($self, $link) = @_;
    $self->{link} = $link;
}

sub all {
    my ($self) = @_;
    my $ua       = LWP::UserAgent->new();
    my $response;
    if ( defined($self->{link}) ) { 
        $response = $ua->post( $URLS{'all'}, { 'api_token' => $self->{api_token}, 'link' => $self->{link} } );
    } else {
        $response = $ua->post( $URLS{'all'}, { 'api_token' => $self->{api_token} } );
    }
    my $rc       = $response->code;
    return $rc;       
}

sub user {
    my ($self, $username) = @_;
    my $ua       = LWP::UserAgent->new();
    my $response;
    if ( defined($self->{link}) ) { 
        $response = $ua->post( $URLS{'user'}, { 'api_token' => $self->{api_token}, 'username' => $username, 'link' => $self->{link} } );
    } else {
        $response = $ua->post( $URLS{'user'}, { 'api_token' => $self->{api_token}, 'username' => $username } );
    }
    my $rc       = $response->code;
    return $rc;       
}

sub subscribers {
    my ($self) = @_;
    my $ua  = LWP::UserAgent->new();
    my $url = $URLS{'subscribers'} . "?api_token=" . $self->{api_token};
    my $response = $ua->get($url);
    my $content  = $response->decoded_content();
    return $content; # return json. example {"result": 123}. let client decode json.
}

sub DESTROY {
    my ($self) = @_;
    $self->{api_token} = undef;
    $self->{link} = undef;
}

1;

