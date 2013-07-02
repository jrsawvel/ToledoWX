#!/usr/bin/perl -wT

# wx-get-conditions.pl - get latest weather conditions at toledo area airports: express, executive (metcalf), suburban

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledotk/Weather/lib";
}

use Weather::Web;
use Data::Dumper;

my $dt = Utils::get_formatted_date_time(); 

my $filename =  Config::get_value_for("htmldir") . Config::get_value_for("wx_conditions_output_file");
if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $filename = $1;
} else {
    die "$dt : Bad data in first argument";	
}

my $xml_url = Config::get_value_for("lucas_county_zone_xml");
my @express_loop = read_xml($xml_url);

$xml_url = Config::get_value_for("toledo_executive_ap");
my @executive_loop = read_xml($xml_url);

$xml_url = Config::get_value_for("toledo_suburban_ap");
my @suburban_loop = read_xml($xml_url);

Web::set_template_name("conditions");
Web::set_template_loop_data("express", \@express_loop);
Web::set_template_loop_data("executive", \@executive_loop);
Web::set_template_loop_data("suburban" , \@suburban_loop);
my $html_output = Web::display_page("Conditions", "returnoutput");
open FILE, ">$filename" or die "$dt : could not create file $filename";
print FILE $html_output;
close FILE;


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
    my @loop;

$result = eval {
    $hash{updatedate} = $tree->{'dwml'}->{'data'}->[1]->{'time-layout'}->{'start-valid-time'}->{'#text'};
    $hash{pressure} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'pressure'}->{'value'};
    $hash{winddirection} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'direction'}->{'value'};
    $hash{windspeedgust} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'wind-speed'}->[0]{'value'};
    $hash{windspeedgustunits} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'wind-speed'}->[0]{'-units'};
    $hash{windspeedsustained} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'wind-speed'}->[1]{'value'};
    $hash{windspeedsustainedunits} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'wind-speed'}->[1]{'-units'};
    $hash{weather} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'weather'}->{'weather-conditions'}->[0]->{'-weather-summary'};
    $hash{visibility} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'weather'}->{'weather-conditions'}->[1]->{'value'}->{'visibility'}->{'#text'};
    $hash{visibilityunits} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'weather'}->{'weather-conditions'}->[1]->{'value'}->{'visibility'}->{'-units'};
    $hash{humidity} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'humidity'}->{'value'};
    $hash{temperature} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'temperature'}->[0]->{'value'};
    $hash{dewpoint} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'temperature'}->[1]->{'value'};
};
unless ($result) {
    die "$dt : problem retrieving xml values from $xml_url."; 
}

    $hash{heatindex} = Utils::get_heat_index($hash{temperature}, $hash{humidity});

    if ( Utils::is_numeric($hash{winddirection}) ) {
        $hash{winddirection} = Utils::wind_direction_degrees_to_cardinal($hash{winddirection});
    } 

    if ( $hash{windspeedsustained} == 0 ) {
        $hash{winddirection} = "Calm";
        $hash{windspeedsustained} = "";
        $hash{windspeedsustainedunits} = "";
    } elsif ( Utils::is_numeric($hash{windspeedsustained}) and $hash{windspeedsustainedunits} eq "knots" ) {
        $hash{windspeedsustained} = Utils::knots_to_mph($hash{windspeedsustained});
        $hash{windspeedsustainedunits} = "mph";
    } 

    if ( Utils::is_numeric($hash{windspeedgust}) and $hash{windspeedgustunits} eq "knots" ) {
        $hash{windspeedgust} = Utils::knots_to_mph($hash{windspeedgust});
        $hash{windspeedgustunits} = "mph";
    } elsif ( !Utils::is_numeric($hash{windspeedgust}) ) {
        $hash{windspeedgust} = "";
        $hash{windspeedgustunits} = "";
    }

    my %tmp_hash1 = Utils::reformat_nws_date_time($hash{updatedate});
    $hash{updatedate} = "$tmp_hash1{date} $tmp_hash1{time} $tmp_hash1{period}";
 
    push(@loop, \%hash);

    return @loop;
}

