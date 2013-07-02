#!/usr/bin/perl -wT

# wx-create-error-page.pl - create page of errors from app

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledotk/Weather/lib";
}

use Weather::Web;

my $dt = Utils::get_formatted_date_time(); # returns format: 24-June-2013 12:23 p.m. EDT

my $filename =  Config::get_value_for("htmldir") . Config::get_value_for("wx_error_output_file");
if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $filename = $1;
} else {
    die "$dt : Bad filename.";	
}

my $error_file = Config::get_value_for("errors_file"); 
if ( $error_file =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $error_file = $1;
} else {
    die "$dt : Bad filename.";
}

open DATA, "<$error_file" or die "can't open file for read.\n";

my $text = "";
while(<DATA>)
{
   $text .= ": " . $_;
}
close DATA;

$text = Utils::newline_to_br($text);

Web::set_template_name("errors");
Web::set_template_variable("back_and_refresh", 1);
Web::set_template_variable("refresh_button_url", Config::get_value_for("errors_home_page")); 
Web::set_template_variable("error_messages", $text);
my $html_output = Web::display_page("Errors", "returnoutput");

open FILE, ">$filename" or die "$dt : could not create file $filename";
print FILE $html_output;
close FILE;
