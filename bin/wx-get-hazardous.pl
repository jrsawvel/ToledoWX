#!/usr/bin/perl -wT

# wx-get-hazardous.pl - hazardous outlook

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledoweather/ToledoWX/lib";
}

use Weather::Web;

my $err = "";

my $dt = Utils::get_formatted_date_time(); # returns format: 24-June-2013 12:23 p.m. EDT

my $url = Config::get_value_for("hazardous_outlook");

my $filename =  Config::get_value_for("htmldir") . Config::get_value_for("wx_hazardous_output_file");
if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $filename = $1;
} else {
    die "$dt : Bad data in first argument";	
}

my $ua = LWP::UserAgent->new;
$ua->timeout(30); # default is 180 secs or 3 mins

#### my $request = HTTP::Request->new( GET => $url );

my $response = $ua->get($url);

if ($response->is_success) {
    my $content = $response->content;

    $content = lc($content);

    if ( $content =~ m/(.*)lez061(.*)this hazardous weather outlook is(.*)/s ) {
        $content = $1 . "<br />" .  $3;
    }

    $content =~ s/^[.]/<br \/>/gm;
    $content = Utils::newline_to_br($content);

    Web::set_template_name("hazardous");
    Web::set_template_variable("hazardous_outlook", $content);
    my $html_output = Web::display_page("Hazardous Outlook", "returnoutput");

    open FILE, ">$filename" or die "$dt : could not create file $filename";
    print FILE $html_output;
    close FILE;
} elsif ( $response->is_error ) {
    $err = "$dt : could not retrieve $url. " . $response->status_line; 
}

if ( $err ) {
    print STDERR $err . "\n";
}



######## old simple get code
## use LWP::Simple;
## my $txt_url = Config::get_value_for("hazardous_outlook");
## my $text = LWP::Simple::get($txt_url);  
## die "Could not retrieve $txt_url" unless $text;
## $text = lc($text);

