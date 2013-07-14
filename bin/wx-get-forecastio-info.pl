#!/usr/bin/perl -wT

# wx-get-forecastio-info.pl - display info from forecast.io json feed

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledotk/ToledoWX/lib";
}

use Weather::Web;
use Weather::ForecastIO;
use Data::Dumper;

my $dt = Utils::get_formatted_date_time(); 

my $filename =  Config::get_value_for("htmldir") . Config::get_value_for("wx_forecastio_output_file");
if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $filename = $1;
} else {
    die "$dt : Bad data in first argument";	
}

my $api_key   = Config::get_value_for("forecastio_api_key");
my $latitude  = Config::get_value_for("forecastio_latitude");
my $longitude = Config::get_value_for("forecastio_longitude");

my $forecastio = ForecastIO->new($api_key, $latitude, $longitude);

#        $forecastio->api_url("http://toledotalk.com/forecastio-json-7.txt");

$forecastio->fetch_data;
my @minutely = $forecastio->minutely;
my @minutely_loop;
if ( @minutely ) {
    foreach my $m ( @minutely ) {
        my %hash;
        $hash{time}              = ForecastIOUtils::format_date( $m->time, "(12hr):(0min) (ap)");
        $hash{date}              = ForecastIOUtils::format_date( $m->time, "(dayname), (monthname) (daynum), (yearfull)");
        $hash{precipType}        = $m->precipType; 
        $hash{precipProbability} = $m->precipProbability * 100; 
        $hash{precipIntensity}   = calc_intensity($m->precipIntensity); 
        $hash{precipcolor}       = calc_precip_color($m->precipIntensity); 
        push(@minutely_loop, \%hash);
    }
}

my $currently = $forecastio->currently;


Web::set_template_name("forecastio");
Web::set_template_variable("back_and_refresh", 1);
Web::set_template_variable("currently_summary", $currently->summary);
Web::set_template_variable("currently_temperature", ForecastIOUtils::round($currently->temperature));
Web::set_template_variable("currently_winddirection", ForecastIOUtils::degrees_to_cardinal($currently->windBearing));
Web::set_template_variable("currently_windspeed", ForecastIOUtils::round($currently->windSpeed));

Web::set_template_variable("minutely_summary", $forecastio->minutelysummary);
Web::set_template_variable("hourly_summary", $forecastio->hourlysummary);
Web::set_template_variable("daily_summary", $forecastio->dailysummary);
Web::set_template_loop_data("minutely" , \@minutely_loop);

my $html_output = Web::display_page("Forecast for Next Hour", "returnoutput");

open (my $fh, ">", $filename) or die "$dt : could not create file $filename";
print $fh $html_output;
close $fh;


# https://developer.forecast.io/docs/v2

#      precipIntensity: A numerical value representing the average expected intensity 
#      (in inches of liquid water per hour) of precipitation occurring at the given 
#      time conditional on probability (that is, assuming any precipitation occurs at all). 
#      A very rough guide is that a value of 0 corresponds to no precipitation, 
#      0.002 corresponds to very light precipitation, 
#      0.017 corresponds to light precipitation, 
#      0.1 corresponds to moderate precipitation, 
#      and 0.4 corresponds to very heavy precipitation.

sub calc_intensity {
    my $intensity = shift;

    my $str = "";

    return $intensity if !$intensity;

    # easier to understand with whole numbers
    $intensity = $intensity * 1000;

    if ( $intensity > 0 and $intensity < 17 ) {
        $str = "very light";
    } elsif ( $intensity >= 17 and $intensity < 50 ) {
        $str = "light";
    } elsif ( $intensity >= 50 and $intensity < 75 ) {
        $str = "light to moderate";
    } elsif ( $intensity >= 75 and $intensity < 125 ) {
        $str = "moderate";
    } elsif ( $intensity >= 125 and $intensity < 200 ) {
        $str = "moderate to heavy";
    } elsif ( $intensity >= 200 and $intensity < 299 ) {
        $str = "heavy";
    } elsif ( $intensity >= 300 and $intensity < 400 ) {
        $str = "heavy to very heavy";
    } elsif ( $intensity >= 400 ) {
        $str = "very heavy";
    }

    return $str;
}

sub calc_precip_color {
    my $intensity = shift;

    my $str = "#000000;";

    return $str if !$intensity;

    # easier to understand with whole numbers
    $intensity = $intensity * 1000;

    if ( $intensity > 0 and $intensity < 17 ) {
        $str = "#c0c0c0;";   # very light
    } elsif ( $intensity >= 17 and $intensity < 50 ) {
        $str = "#888888;";   # light
    } elsif ( $intensity >= 50 and $intensity < 75 ) {
        $str = "#006600;";   # light to moderate
    } elsif ( $intensity >= 75 and $intensity < 125 ) {
        $str = "#cccc00;";   # moderate - dark green-yellow
    } elsif ( $intensity >= 125 and $intensity < 200 ) {
        $str = "#cc6600;";   # moderate to heavy - dark orange
    } elsif ( $intensity >= 200 and $intensity < 299 ) {
        $str = "#cc0000;";   # heavy - dark red
    } elsif ( $intensity >= 300 and $intensity < 400 ) {
        $str = "#990066;";   # heavy to very heavy - dark purple
    } elsif ( $intensity >= 400 ) {
        $str = "#000099;";   # very heavy - dark blue
    }

    return $str;
}

__END__

my arbitrary breaks 
0 = none

1
2 = very light
16

17 = light
49

50
??? = light to moderate
74

75
100 = moderate
124

125
??? = moderate to heavy
199

200
250 = heavy
299

300
 = heavy to very heavy
399

400+ = very heavy


