#!/usr/bin/perl -wT

# wx-get-hourly-forecast.pl - display hourly forecast for next 24 hours

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledotk/Weather/lib";
}

use Weather::Web;
use Data::Dumper;

my $dt = Utils::get_formatted_date_time(); 

my $filename =  Config::get_value_for("htmldir") . Config::get_value_for("wx_hourly_forecast_output_file");
if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $filename = $1;
} else {
    die "$dt : Bad data in first argument";	
}

my $xml_url = Config::get_value_for("lucas_county_hourly_forecast_xml");
my %hash = read_xml($xml_url);

my @express_loop = merge_data(\%hash);

Web::set_template_name("hourlyforecast");
Web::set_template_loop_data("express" , \@express_loop);
my $html_output = Web::display_page("Hourly Forecast", "returnoutput");

open (my $fh, ">", $filename) or die "$dt : could not create file $filename";
print $fh $html_output;
close $fh;

# open FILE, ">$filename" or die "$dt : could not create file $filename";
# print FILE $html_output;
# close FILE;


sub read_xml {
    my $xml_url = shift;

    my $result;

    my $dt = Utils::get_formatted_date_time(); 

    my $ua = LWP::UserAgent->new;
    $ua->timeout(30); 
    my $response = $ua->get($xml_url);
    if ( $response->is_error ) {
       die "$dt : could not retrieve $xml_url. " . $response->status_line; 
    }

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

    my %hash;

    # use temp, wind speed, wind direction, sky cover %, and precip chance
    # allegedly, the wind speed is listed in mph. units not given in xml file, but web page version says mph.
    # store references to arrays within a hash;
    # wind direction is in degrees
    # precip chance in percent
    # cloud amount in percent

$result = eval {
    $hash{starttime}     = $tree->{'dwml'}->{'data'}->{'time-layout'}->{'start-valid-time'};
    $hash{temperature}   = $tree->{'dwml'}->{'data'}->{'parameters'}->{'temperature'}->[0]->{'value'};
    $hash{winddirection} = $tree->{'dwml'}->{'data'}->{'parameters'}->{'direction'}->{'value'};
    $hash{windspeed}     = $tree->{'dwml'}->{'data'}->{'parameters'}->{'wind-speed'}->[0]->{'value'};
    $hash{precipchance}  = $tree->{'dwml'}->{'data'}->{'parameters'}->{'probability-of-precipitation'}->{'value'};
    $hash{cloudamount}   = $tree->{'dwml'}->{'data'}->{'parameters'}->{'cloud-amount'}->{'value'};
};
unless ($result) {
    die "$dt : problem retrieving xml values from $xml_url."; 
}

    return %hash;
}


sub merge_data {
    my $hash_ref = shift;   # hash ref containing an array of ref

    my @loop;

    for (my $i=0; $i<24; $i++) {
        my %hash = ();

        $hash{temperature}  = $hash_ref->{temperature}->[$i];
        $hash{windspeed}    = $hash_ref->{windspeed}->[$i];
        $hash{precipchance} = $hash_ref->{precipchance}->[$i];
        $hash{cloudamount}  = $hash_ref->{cloudamount}->[$i];

        if ( Utils::is_numeric($hash_ref->{winddirection}->[$i]) ) {
            $hash{winddirection} = Utils::wind_direction_degrees_to_cardinal($hash_ref->{winddirection}->[$i]);
        } 
        my %tmp_hash = Utils::reformat_nws_date_time($hash_ref->{starttime}->[$i]);
        $hash{starttime} = "$tmp_hash{time} $tmp_hash{period}";
        $hash{startdate} = $tmp_hash{date};

        push(@loop, \%hash);
    }

    return @loop;
}



