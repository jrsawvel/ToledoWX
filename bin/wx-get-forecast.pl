#!/usr/bin/perl -wT

# wx-get-forecast.pl

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledotk/Weather/lib";
}

use Weather::Web;
use Data::Dumper;

my $dt = Utils::get_formatted_date_time(); # returns format: 24-June-2013 12:23 p.m. EDT
my $filename =  Config::get_value_for("htmldir") . Config::get_value_for("wx_forecast_output_file");
if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $filename = $1;
} else {
    die "$dt : Bad filename."; 
}

my $xml_url = Config::get_value_for("lucas_county_zone_xml");

my $ua = LWP::UserAgent->new;
$ua->timeout(30); 
my $response = $ua->get($xml_url);
if ( $response->is_error ) {
   die "$dt : could not retrieve $xml_url. " . $response->status_line; 
}

my $result;
my $tree = "";

$result = eval {
    my $content = $response->content;
    my $tpp = XML::TreePP->new();
    $tree = $tpp->parse($content);
    # exit unless $tree;
};
unless ($result) {
    die "$dt : could not parse $xml_url."; 
}

if ( !$tree ) {
    die "$dt : could not parse $xml_url."; 
}

my $creation_date = $tree->{'dwml'}->{'head'}->{'product'}->{'creation-date'}->{'#text'};

# print 7-day forecast
my @forecast_array = "";
my $forecast_array_ref = $tree->{'dwml'}->{'data'}->[0]->{'parameters'}->{'wordedForecast'}->{'text'};
foreach my $f ( @$forecast_array_ref) {
    # print $f . "\n";
    push(@forecast_array, $f);
}

# time period - day and night names (Thursday, Thursday Night)
# reference to arrary of hashes
my @time_period_array = "";

for (my $x=0; $x<10; $x++ ) {
    my $time_period_array_ref = $tree->{'dwml'}->{'data'}->[0]->{'time-layout'}->[$x]->{'start-valid-time'};
    if ( ref $time_period_array_ref eq ref [] ) {
        foreach my $t ( @$time_period_array_ref ) {
            push(@time_period_array, $t->{'-period-name'});
        }
        last;
    }
}
  
my $forecast_len = @forecast_array;
my $time_period_len = @time_period_array;

my @loop;
my $ctr;

# unsure why element [0] is empty but it's proper to start with 1
for ($ctr=1; $ctr < $forecast_len; $ctr++) {
    my %hash;
    # print $time_period_array[$ctr] . ": " . $forecast_array[$ctr] . "\n";
    $hash{period} = $time_period_array[$ctr];
    $hash{forecast} = $forecast_array[$ctr];
    push(@loop, \%hash);
} 

my %tmp_hash = Utils::reformat_nws_date_time($creation_date);
$creation_date = "$tmp_hash{date} $tmp_hash{time} $tmp_hash{period}";

Web::set_template_name("forecast");
Web::set_template_loop_data("forecast", \@loop);
Web::set_template_variable("lastupdate", $creation_date);

my $html_output = Web::display_page("Forecast", "returnoutput");
open FILE, ">$filename" or die "$dt : could not create file $filename";
print FILE $html_output;
close FILE;

