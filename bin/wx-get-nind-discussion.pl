#!/usr/bin/perl -wT

# wx-get-discussion.pl - northern indiana area forecast discussion

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledotk/ToledoWX/lib";
}

use Weather::Web;
    
my $dt = Utils::get_formatted_date_time(); # returns format: 24-June-2013 12:23 p.m. EDT
my $filename =  Config::get_value_for("htmldir") . Config::get_value_for("wx_nind_discussion_output_file");
if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $filename = $1;
} else {
    die "$dt : Bad filename $filename."; 
}
my $url = Config::get_value_for("nind_forecast_discussion");

my $ua = LWP::UserAgent->new;
$ua->timeout(30); # default is 180 secs or 3 mins
my $response = $ua->get($url);
if ( $response->is_error ) {
    die "$dt : could not retrieve $url. " . $response->status_line; 
}

my $content = $response->content;
$content =~ s/^[.]/<br \/>/gm;
$content = Utils::newline_to_br($content);
$content = lc($content);

Web::set_template_name("discussion");
Web::set_template_variable("forecast_discussion", $content);
Web::set_template_variable("back_and_home", 1);
Web::set_template_variable("back_button_url", Config::get_value_for("afds_home_page")); 
my $html_output = Web::display_page("Northern Indiana Area Forecast Discussion", "returnoutput");

open FILE, ">$filename" or die "$dt : could not create file $filename";
print FILE $html_output;
close FILE;
