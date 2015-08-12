#!/usr/bin/perl -wT

# wx-create-external-links-page.pl - create page with external links: nws, wunderground, toledo talk

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledoweather/ToledoWX/lib";
}

use Weather::Web;

my $dt = Utils::get_formatted_date_time(); 
my $filename =  Config::get_value_for("htmldir") . Config::get_value_for("wx_links_output_file");
if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $filename = $1;
} else {
    die "$dt : Bad filename $filename."; 
}
    
Web::set_template_name("links");
my $html_output = Web::display_page("External Links", "returnoutput");

open FILE, ">$filename" or die "$dt : could not create file $filename";
print FILE $html_output;
close FILE;
