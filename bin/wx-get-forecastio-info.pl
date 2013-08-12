#!/usr/bin/perl -wT

# wx-get-forecastio-info.pl - display info from forecast.io json feed

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledotk/ToledoWX/lib";
}

use Weather::Web;
use Weather::ForecastIO;
use Weather::DateTimeFormatter;
use Data::Dumper;

my $dt = Utils::get_formatted_date_time(); 

my $wind_speed = 0;
my $wind_direction = "";

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
my @toledo_minutely_loop;
if ( @minutely ) {
    foreach my $m ( @minutely ) {
        my %hash;
        $hash{time}              = DateTimeFormatter::create_date_time_stamp_local( $m->time, "(12hr):(0min) (ap)");
        $hash{date}              = DateTimeFormatter::create_date_time_stamp_local( $m->time, "(dayname), (monthname) (daynum), (yearfull)");
        $hash{precipType}        = $m->precipType; 
        $hash{precipProbability} = $m->precipProbability * 100; 
        $hash{precipIntensity}   = ForecastIOUtils::calc_intensity($m->precipIntensity); 
        $hash{precipcolor}       = ForecastIOUtils::calc_intensity_color($m->precipIntensity); 
        push(@toledo_minutely_loop, \%hash);
    }
}

my $currently = $forecastio->currently;

Web::set_template_name("forecastio");
Web::set_template_variable("back_and_refresh", 1);
Web::set_template_variable("currently_summary", $currently->summary);
Web::set_template_variable("currently_temperature", ForecastIOUtils::round($currently->temperature));

my $daily_summary;
my $current_date_time = Utils::get_formatted_date_time(); 
# my $result = eval {
    $wind_direction = ForecastIOUtils::degrees_to_cardinal($currently->windBearing);
    $wind_speed     = ForecastIOUtils::round($currently->windSpeed);
    $wind_speed = 0 if $wind_speed eq "undef";
    $wind_direction = "Calm wind" if $wind_speed == 0; 
    $daily_summary = $forecastio->dailysummary;
    $daily_summary =~ s|\x{b0}|&deg;| if $daily_summary;
# };
# unless ($result) {
#    die "$current_date_time : error $result";
# }
Web::set_template_variable("currently_winddirection", $wind_direction);
Web::set_template_variable("currently_windspeed", $wind_speed);
Web::set_template_variable("hourly_summary", $forecastio->hourlysummary);
Web::set_template_variable("daily_summary", $daily_summary);
Web::set_template_variable("toledo_latitude", $latitude);
Web::set_template_variable("toledo_longitude", $longitude);

#### Sylvania
$latitude  = Config::get_value_for("sylvania_forecastio_latitude");
$longitude = Config::get_value_for("sylvania_forecastio_longitude");
my $sylvania_forecastio = ForecastIO->new($api_key, $latitude, $longitude);
$sylvania_forecastio->fetch_data;
my @sylvania_minutely = $sylvania_forecastio->minutely;
my @sylvania_minutely_loop;
if ( @sylvania_minutely ) {
    foreach my $m ( @sylvania_minutely ) {
        my %hash;
        $hash{time}              = DateTimeFormatter::create_date_time_stamp_local( $m->time, "(12hr):(0min) (ap)");
        $hash{date}              = DateTimeFormatter::create_date_time_stamp_local( $m->time, "(dayname), (monthname) (daynum), (yearfull)");
        $hash{precipType}        = $m->precipType; 
        $hash{precipProbability} = $m->precipProbability * 100; 
        $hash{precipIntensity}   = ForecastIOUtils::calc_intensity($m->precipIntensity); 
        $hash{precipcolor}       = ForecastIOUtils::calc_intensity_color($m->precipIntensity); 
        push(@sylvania_minutely_loop, \%hash);
    }
}


#### Maumee
# $latitude  = Config::get_value_for("maumee_forecastio_latitude");
# $longitude = Config::get_value_for("maumee_forecastio_longitude");
# my $maumee_forecastio = ForecastIO->new($api_key, $latitude, $longitude);
# $maumee_forecastio->fetch_data;
# my @maumee_minutely = $maumee_forecastio->minutely;
# my @maumee_minutely_loop;
# if ( @maumee_minutely ) {
#     foreach my $m ( @maumee_minutely ) {
#        my %hash;
#        $hash{time}              = DateTimeFormatter::create_date_time_stamp_local( $m->time, "(12hr):(0min) (ap)");
#        $hash{date}              = DateTimeFormatter::create_date_time_stamp_local( $m->time, "(dayname), (monthname) (daynum), (yearfull)");
#        $hash{precipType}        = $m->precipType; 
#        $hash{precipProbability} = $m->precipProbability * 100; 
#        $hash{precipIntensity}   = ForecastIOUtils::calc_intensity($m->precipIntensity); 
#        $hash{precipcolor}       = ForecastIOUtils::calc_intensity_color($m->precipIntensity); 
#        push(@maumee_minutely_loop, \%hash);
#    }
# }


#### Oregon
$latitude  = Config::get_value_for("oregon_forecastio_latitude");
$longitude = Config::get_value_for("oregon_forecastio_longitude");
my $oregon_forecastio = ForecastIO->new($api_key, $latitude, $longitude);
$oregon_forecastio->fetch_data;
my @oregon_minutely = $oregon_forecastio->minutely;
my @oregon_minutely_loop;
if ( @oregon_minutely ) {
    foreach my $m ( @oregon_minutely ) {
        my %hash;
        $hash{time}              = DateTimeFormatter::create_date_time_stamp_local( $m->time, "(12hr):(0min) (ap)");
        $hash{date}              = DateTimeFormatter::create_date_time_stamp_local( $m->time, "(dayname), (monthname) (daynum), (yearfull)");
        $hash{precipType}        = $m->precipType; 
        $hash{precipProbability} = $m->precipProbability * 100; 
        $hash{precipIntensity}   = ForecastIOUtils::calc_intensity($m->precipIntensity); 
        $hash{precipcolor}       = ForecastIOUtils::calc_intensity_color($m->precipIntensity); 
        push(@oregon_minutely_loop, \%hash);
    }
}


Web::set_template_variable("sylvania_minutely_summary", $sylvania_forecastio->minutelysummary);
Web::set_template_loop_data("sylvania_minutely" , \@sylvania_minutely_loop);

# Web::set_template_variable("maumee_minutely_summary", $maumee_forecastio->minutelysummary);
# Web::set_template_loop_data("maumee_minutely" , \@maumee_minutely_loop);

Web::set_template_variable("toledo_minutely_summary", $forecastio->minutelysummary);
Web::set_template_loop_data("toledo_minutely" , \@toledo_minutely_loop);

Web::set_template_variable("oregon_minutely_summary", $oregon_forecastio->minutelysummary);
Web::set_template_loop_data("oregon_minutely" , \@oregon_minutely_loop);


my $html_output = Web::display_page("Forecast for Next Hour", "returnoutput");

open (my $fh, ">", $filename) or die "$dt : could not create file $filename";
print $fh $html_output;
close $fh;


