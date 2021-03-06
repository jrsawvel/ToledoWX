#!/usr/bin/perl -wT

# wx-get-marine-forecast.pl

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledoweather/ToledoWX/lib";
}

use Weather::Web;

my $dt = Utils::get_formatted_date_time(); 

my $filename =  Config::get_value_for("htmldir") . Config::get_value_for("wx_marine_output_file");
if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $filename = $1;
} else {
    die "$dt : Bad data in first argument";	
}

my $url = Config::get_value_for("marine_forecast");

my $ua = LWP::UserAgent->new;
$ua->timeout(30); 
my $response = $ua->get($url);
if ( $response->is_error ) {
    die "$dt : could not retrieve $url. " . $response->status_line; 
}

my $content = $response->content;
$content = lc($content);
# $content =~ s/^[.]/<br \/>/gm;
if ( $content =~ m/<pre class="glossaryproduct">(.*)<\/pre>/s ) {
    $content = $1;        
}

$content = Utils::trim_spaces($content);
$content = Utils::newline_to_br($content);


Web::set_template_name("marine");
Web::set_template_variable("marineforecast", $content);
my $html_output = Web::display_page("Marine Forecast", "returnoutput");

open (my $fh, ">", $filename) or die "$dt : could not create file $filename";
print $fh $html_output;
close $fh;
