#!/usr/bin/perl -wT

# wx-get-afds.pl - area forecast discussions

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledoweather/ToledoWX/lib";
}

use Weather::Web;

my $dt = Utils::get_formatted_date_time(); # returns format: 24-June-2013 12:23 p.m. EDT

my $filename =  Config::get_value_for("htmldir") . Config::get_value_for("wx_afds_output_file");
if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $filename = $1;
} else {
    die "$dt : Bad filename $filename."; 
}

my $cleveland = get_afd( Config::get_value_for("forecast_discussion") );
my $detroit   = get_afd( Config::get_value_for("det_forecast_discussion") );
my $indiana   = get_afd( Config::get_value_for("nind_forecast_discussion") );

Web::set_template_name("afds");
Web::set_template_variable("cleveland", $cleveland);
Web::set_template_variable("detroit",   $detroit);
Web::set_template_variable("indiana",   $indiana);
my $html_output = Web::display_page("Area Forecast Discussions", "returnoutput");
open FILE, ">$filename" or die "$dt : could not create file $filename";
print FILE $html_output;
close FILE;


sub get_afd {
    my $url = shift;

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

    return $content;
}

