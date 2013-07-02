#!/usr/bin/perl -wT

# wx-create-more-radars-maps-page.pl - html page with more embedded images of radars and maps

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledotk/Weather/lib";
}

use Weather::Web;
    
my $dt = Utils::get_formatted_date_time(); 
my $filename =  Config::get_value_for("htmldir") . Config::get_value_for("wx_more_radars_maps_output_file");
if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $filename = $1;
} else {
    die "$dt : Bad filename."; 
}

Web::set_template_name("moreradarsmaps");
Web::set_template_variable("imagehome", Config::get_value_for("imagehome"));
Web::set_template_variable("back_and_refresh", 1);
Web::set_template_variable("refresh_button_url", Config::get_value_for("more_radars_maps_home_page")); 
my $html_output = Web::display_page("More Radars and Maps", "returnoutput");

open FILE, ">$filename" or die "$dt : could not create file $filename";
print FILE $html_output;
close FILE;
