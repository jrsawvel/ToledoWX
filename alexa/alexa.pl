#!/usr/bin/perl -wT

use strict;
use warnings;
use diagnostics;

$|++;

BEGIN {
    unshift @INC, "/home/toledoweather/ToledoWX/lib";
}

use Data::Dumper;
use Time::Local;
use JSON::PP;
use XML::TreePP;
use XML::FeedPP;
use LWP::Simple;
use LWP::UserAgent;

use Weather::Web;



my $conditions_html = get_conditions();
my $conditions_text = Utils::remove_html   ($conditions_html);
   $conditions_text = Utils::remove_newline($conditions_text);

my $forecast_html = get_forecast();
my $forecast_text = Utils::remove_html   ($forecast_html);
   $forecast_text = Utils::remove_newline($forecast_text);

my $afd_html = get_afd();
my $afd_text = Utils::remove_html   ($afd_html);
   $afd_text = Utils::remove_newline($afd_text);

my @alerts  = get_alerts();
my @md      = get_mesoscale_info();
my @hazards = get_hazards();

my $alerts_rss = create_rss(\@alerts, \@md, \@hazards); 

my $concerned_statements = parse_alerts_rss($alerts_rss);

my $plain_text_briefing = $concerned_statements . " " . $conditions_text . " " . $afd_text . " " . $forecast_text;
$plain_text_briefing =~ s|  | |g;

output_briefing_html($conditions_html, $forecast_html, $afd_html, $concerned_statements);
# output_briefing_json($plain_text_briefing);
output_briefing_json_multiple($concerned_statements, $conditions_text, $afd_text, $forecast_text);



########################################################


sub output_briefing_html {
    my $conditions = shift;
    my $forecast   = shift;
    my $afd        = shift;
    my $concerned  = shift;


    my $date_time = Utils::get_formatted_date_time(); 

    Web::set_template_name("alexa-flash-briefing");
    Web::set_template_variable("conditions", $conditions);
    Web::set_template_variable("forecast", $forecast);
    Web::set_template_variable("afdsynopsis", $afd);
    Web::set_template_variable("concerned_statements", $concerned);

    my $briefing = Web::display_page("Alexa Flash Briefing", "returnoutput");

    my $filename =  Config::get_value_for("htmldir") . Config::get_value_for("alexa_flash_briefing_html");
    if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $filename = $1;
    } else {
        die "$date_time: Bad filename."; 
    }

    open FILE, ">$filename" or die "$date_time: could not create file $filename";
    print FILE $briefing;
    close FILE;
}



sub output_briefing_json {
    my $main_text = shift;


    my $date_time = Utils::get_formatted_date_time(); 

    my $epochsecs = time();
    my ($sec, $min, $hr, $mday, $mon, $yr)  = (gmtime($epochsecs))[0,1,2,3,4,5];
    my $update_date = sprintf "%04d-%02d-%02dT%02d:%02d:%02d.0Z", 2000 + $yr-100, $mon+1, $mday, $hr, $min, $sec;

    my $hash_ref;
    $hash_ref->{uid}              = $epochsecs;
    $hash_ref->{updateDate}       = $update_date;
    $hash_ref->{titleText}        = 'Current Toledo Weather';
    $hash_ref->{mainText}         = $main_text;
    $hash_ref->{redirectionUrl}   = 'http://toledoweather.info/briefing.html';
    my $json_str = encode_json $hash_ref;

    my $json_filename =  Config::get_value_for("htmldir") . Config::get_value_for("alexa_flash_briefing_json");
    if ( $json_filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $json_filename = $1;
    } else {
        die "$date_time: Bad JSON filename."; 
    }

    open FILE, ">$json_filename" or die "$date_time: could not create file $json_filename";
    print FILE $json_str;
    close FILE;
}


sub output_briefing_json_multiple {
    my $important  = shift;
    my $conditions = shift;
    my $synopsis   = shift;
    my $forecast   = shift;

    my @arr;

    my $date_time = Utils::get_formatted_date_time(); 

    my $epochsecs = time();
    my ($sec, $min, $hr, $mday, $mon, $yr)  = (gmtime($epochsecs))[0,1,2,3,4,5];
    my $update_date = sprintf "%04d-%02d-%02dT%02d:%02d:%02d.0Z", 2000 + $yr-100, $mon+1, $mday, $hr, $min, $sec;


    my $hash_ref;
    $hash_ref->{uid}              = $epochsecs . "-1" ;
    $hash_ref->{updateDate}       = $update_date;
    $hash_ref->{titleText}        = 'Important Statements';
    $hash_ref->{mainText}         = $important;
    $hash_ref->{redirectionUrl}   = 'http://toledoweather.info/hazardous-weather-outlook.html';
    push(@arr, $hash_ref);


    $hash_ref = undef;
    $hash_ref->{uid}              = $epochsecs . "-2" ;
    $hash_ref->{updateDate}       = $update_date;
    $hash_ref->{titleText}        = 'Current Conditions';
    $hash_ref->{mainText}         = $conditions;
    $hash_ref->{redirectionUrl}   = 'http://toledoweather.info/current-conditions.html';
    push(@arr, $hash_ref);


    $hash_ref = undef;
    $hash_ref->{uid}              = $epochsecs . "-3" ;
    $hash_ref->{updateDate}       = $update_date;
    $hash_ref->{titleText}        = 'Synopsis';
    $hash_ref->{mainText}         = $synopsis;
    $hash_ref->{redirectionUrl}   = 'http://toledoweather.info/area-forecast-discussions.html';
    push(@arr, $hash_ref);


    $hash_ref = undef;
    $hash_ref->{uid}              = $epochsecs . "-4" ;
    $hash_ref->{updateDate}       = $update_date;
    $hash_ref->{titleText}        = 'Forecast';
    $hash_ref->{mainText}         = $forecast;
    $hash_ref->{redirectionUrl}   = 'http://toledoweather.info/forecast.html';
    push(@arr, $hash_ref);


    my $json_str = encode_json \@arr;


    my $json_filename =  Config::get_value_for("htmldir") . Config::get_value_for("alexa_flash_briefing_json");
    if ( $json_filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $json_filename = $1;
    } else {
        die "$date_time: Bad JSON filename."; 
    }

    open FILE, ">$json_filename" or die "$date_time: could not create file $json_filename";
    print FILE $json_str;
    close FILE;
}

sub get_conditions {

my $dt = Utils::get_formatted_date_time(); 

my $xml_url;

$xml_url = Config::get_value_for("lucas_county_zone_xml");
my @express_loop = read_xml($xml_url);

Web::set_template_name("alexa-conditions-min");

if ( $express_loop[0]->{error}  ne "yes" ) {
    delete($express_loop[0]->{error}); 
    Web::set_template_loop_data("express",   \@express_loop)   
}


my $html_output = Web::display_page_min();

return $html_output;

}


sub read_xml {
    my $xml_url = shift;

    my $result;

    my $dt = Utils::get_formatted_date_time(); 

    my $ua = LWP::UserAgent->new;
    $ua->timeout(30); 
    my $response = $ua->get($xml_url);
    if ( $response->is_error ) {
        warn "$dt : warning : first attempt : could not retrieve $xml_url. " . $response->status_line . "\n"; 
        $ua->timeout(30); 
        $response = $ua->get($xml_url);
        if ( $response->is_error ) {
           die "$dt : program die : second and final attempt : could not retrieve $xml_url. " . $response->status_line; 
        }
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
#    $hash{pressure} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'pressure'}->{'value'};
    $hash{winddirection} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'direction'}->{'value'};
    $hash{windspeedgust} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'wind-speed'}->[0]{'value'};
    $hash{windspeedgustunits} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'wind-speed'}->[0]{'-units'};
    $hash{windspeedsustained} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'wind-speed'}->[1]{'value'};
    $hash{windspeedsustainedunits} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'wind-speed'}->[1]{'-units'};
    $hash{weather} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'weather'}->{'weather-conditions'}->[0]->{'-weather-summary'};
#    $hash{visibility} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'weather'}->{'weather-conditions'}->[1]->{'value'}->{'visibility'}->{'#text'};
#    $hash{visibilityunits} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'weather'}->{'weather-conditions'}->[1]->{'value'}->{'visibility'}->{'-units'};
    $hash{humidity} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'humidity'}->{'value'};
    $hash{temperature} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'temperature'}->[0]->{'value'};
#    $hash{dewpoint} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'temperature'}->[1]->{'value'};
    $hash{error} = "no";
};
unless ($result) {
#    die "$dt : problem retrieving xml values from $xml_url."; 
    $hash{error} = "yes";
    push(@loop, \%hash);
    return @loop;
}

    $hash{heatindex} = Utils::get_heat_index($hash{temperature}, $hash{humidity});


    if ( Utils::is_numeric($hash{winddirection}) ) {
        $hash{winddirection} = Utils::wind_direction_degrees_to_cardinal_full_names($hash{winddirection});
    } 

# test $hash{windspeedsustained} = "NA";

    if ( !$hash{weather} or length($hash{weather}) < 2 ) {
        $hash{weather} = "unavailable";
    }

    $hash{iscalmwind} = 0;

    if ( !Utils::is_numeric($hash{windspeedsustained}) or $hash{windspeedsustained} == 0 ) {
        $hash{winddirection} = "calm";
        $hash{windspeedsustained} = "";
        $hash{windspeedsustainedunits} = "";
        $hash{iscalmwind} = 1;
    } elsif ( Utils::is_numeric($hash{windspeedsustained}) and $hash{windspeedsustainedunits} eq "knots" ) {
        $hash{windspeedsustained} = Utils::knots_to_mph($hash{windspeedsustained});
        $hash{windspeedsustainedunits} = "miles per hour";
        $hash{windchill} = Utils::get_wind_chill($hash{temperature}, $hash{windspeedsustained});
        if ( $hash{windchill} != 999 ) {
            $hash{windchillexists} = 1;
        }
    } 

    if ( Utils::is_numeric($hash{windspeedgust}) and $hash{windspeedgustunits} eq "knots" ) {
        $hash{windspeedgust} = Utils::knots_to_mph($hash{windspeedgust});
        $hash{windspeedgustunits} = "miles per hour";
    } elsif ( !Utils::is_numeric($hash{windspeedgust}) ) {
        $hash{windspeedgust} = "";
        $hash{windspeedgustunits} = "";
    }

    my %tmp_hash1 = Utils::reformat_nws_date_time($hash{updatedate});
    $hash{updatedate} = "$tmp_hash1{date} $tmp_hash1{time} $tmp_hash1{period}";
 
    push(@loop, \%hash);

    return @loop;
}








########################################


sub get_forecast {

my $dt = Utils::get_formatted_date_time(); # returns format: 24-June-2013 12:23 p.m. EDT

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
    $f =~ s|mph|miles per hour|igs;
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

### sep 21, 2017 - for amazon echo alexa flash briefing feed, will only pull off the first 36 to 60 hours 
### of the forecast. the firt 3 to 5 elements. will start with first 5 elements.


# unsure why element [0] is empty but it's proper to start with 1
# for ($ctr=1; $ctr < $forecast_len; $ctr++) {
for ($ctr=1; $ctr < 6; $ctr++) {
    my %hash;
    # print $time_period_array[$ctr] . ": " . $forecast_array[$ctr] . "\n";
    $hash{period} = $time_period_array[$ctr];
    $hash{forecast} = $forecast_array[$ctr];
    push(@loop, \%hash);
} 

my %tmp_hash = Utils::reformat_nws_date_time($creation_date);
$creation_date = "$tmp_hash{date} $tmp_hash{time} $tmp_hash{period}";

Web::set_template_name("alexa-forecast-min");
Web::set_template_loop_data("forecast", \@loop);
Web::set_template_variable("lastupdate", $creation_date);

my $html_output = Web::display_page_min();

return $html_output;

}




#########################################################



sub get_afd {

my $dt = Utils::get_formatted_date_time(); # returns format: 24-June-2013 12:23 p.m. EDT

my $url = Config::get_value_for("forecast_discussion");

my $ua = LWP::UserAgent->new;
$ua->timeout(30); # default is 180 secs or 3 mins
my $response = $ua->get($url);
if ( $response->is_error ) {
    die "$dt : could not retrieve $url. " . $response->status_line; 
}

my $content = $response->content;

my $synopsis;

if ( $content =~ m|SYNOPSIS(\.*)([^&]*)|s ) {
    $synopsis = $2;
    $synopsis =~ s|[\r\n]| |gs;
}

Web::set_template_name("alexa-afd-min");
Web::set_template_variable("afdsynopsis", $synopsis); 

my $html_output = Web::display_page_min();

return $html_output;


}


#####################################################




sub get_mesoscale_info {

    my @array = ();
    
    # reference to an array of hasshes
    # for testing my $mdtree = read_and_parse_xml_file("http://toledotalk.com/spcmdrss.xml");
    my $mdtree = read_and_parse_xml_file("http://www.spc.noaa.gov/products/spcmdrss.xml");

    my $mdarrref = $mdtree->{'rss'}->{'channel'}->{'item'};
    if ( ref $mdarrref eq ref [] ) {
        foreach my $mditem ( @$mdarrref ) {
            my %hash = process_md_hash_ref($mditem);
            push(@array, \%hash) if %hash;
        }
    }  else {
            my %hash = process_md_hash_ref($mdarrref);
            push(@array, \%hash) if %hash;
    }

    return @array;
}


sub process_md_hash_ref {
    my $mditem = shift;

    my %mdhash = ();
    my $mdtitle = $mditem->{'title'};
    my $mdlink = $mditem->{'link'};
    my $mdpubdate = $mditem->{'pubDate'};
    my $mddesc = $mditem->{'description'};

    if ( regional_md($mddesc) ) {
        $mdhash{'title'}= $mdtitle;
        $mdhash{'link'}= $mdlink;
        $mdhash{'pubDate'}= $mdpubdate;
    } 

    return %mdhash;
}


# attn...wfo...
# if (  $mddesc =~ m/CLE/s   or  $mddesc =~ m/DTX/s  or  $mddesc =~ m/IWX/s  ) {
sub regional_md {
    my $str = shift;
    my $return_val = 0;

    if ( $str =~ m/attn(.*)wfo(.*)/is ) {
        my $tmp_str = $2;
        if (  $tmp_str =~ m/CLE/s   or  $tmp_str =~ m/DTX/s  or  $tmp_str =~ m/IWX/s  ) {
            $return_val = 1;
        }
    }    

    return $return_val;
}

sub read_and_parse_xml_file {
    my $xml_url = shift;

    my $ua = LWP::UserAgent->new;
    $ua->timeout(30); 
    my $response = $ua->get($xml_url);
    if ( $response->is_error ) {
       die "could not retrieve $xml_url. " . $response->status_line; 
    }

    my $result;
    my $tree = "";

    $result = eval {
        my $content = $response->content;
        my $tpp = XML::TreePP->new();
        $tree = $tpp->parse($content);
    };

    unless ($result) {
        die "could not parse $xml_url."; 
    }

    if ( !$tree ) {
        die "could not parse $xml_url."; 
    }

    return $tree;
}


sub get_alerts {
    my @array = ();

    my $xml = "http://alerts.weather.gov/cap/wwaatmget.php?x=OHC095&y=0";
    
    my $feed = XML::FeedPP->new($xml);

    die "could not retrieve feed $xml" if !$feed;

    foreach my $item ( $feed->get_item() ) {
        my %hash;
        $hash{'link'}  = $item->link();
        # $hash{'title'} = $item->title();
        $hash{'title'} = $item->get("cap:event");
        # $hash{'desc'}  = $item->description();
        $hash{'pubDate'}  = reformat_nws_date_time($item->pubDate());
        push(@array, \%hash); 
    }

    return @array;
}

sub get_hazards {
  
    my @array = ();

    my $json_hash_ref = read_and_parse_json_file();

    my $hazard_text_array = $json_hash_ref->{'data'}->{'hazard'};
    my $hazard_url_array  = $json_hash_ref->{'data'}->{'hazardUrl'};
    my $array_len = @$hazard_text_array;

    for (my $i=0; $i<$array_len; $i++) {
        my %hash;

        my $hazard  = $hazard_text_array->[$i]; 
        if ( $hazard eq "Hazardous Weather Outlook" ) {
            $hash{'title'}  = $hazard;
            $hash{'link'}   = $hazard_url_array->[$i];
            $hash{'pubDate'}  = "";
            push(@array, \%hash); 
        }
        elsif ( $hazard eq "Short Term Forecast" ) {
            $hash{'title'}  = $hazard;
            $hash{'link'}   = $hazard_url_array->[$i];
            $hash{'pubDate'}  = "";
            push(@array, \%hash); 
        }
    }

    return @array;
}

sub read_and_parse_json_file {

    my $json_url = "http://forecast.weather.gov/MapClick.php?lat=41.61000&lon=-83.8&unit=0&lg=english&FcstType=json";

# boston
# $json_url = "http://forecast.weather.gov/MapClick.php?lat=42.3&lon=-71.1167&unit=0&lg=english&FcstType=json";

    my $ua = LWP::UserAgent->new;
    $ua->timeout(30); 
    my $response = $ua->get($json_url);
    if ( $response->is_error ) {
       die "could not retrieve $json_url. " . $response->status_line; 
    }

    my $result;
    my $tree = "";

    $result = eval {
        my $content = $response->content;
        $tree = decode_json $content;
    };

    unless ($result) {
        die "could not parse $json_url."; 
    }

    if ( !$tree ) {
        die "could not parse $json_url."; 
    }

    return $tree;
}


# not perfect, validated rss but good enough for usage in this script.
sub create_rss {
    # array refs to hash refs
    my $alerts  = shift;
    my $md      = shift;
    my $hazards = shift;

    my $pub_date = create_date_time_stamp();


    my $rss = <<EORSS1;
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:rss5="http://rss5.org/">
  <channel>
   <title>Toledo Weather Messages</title>
   <link>http://toledotalk.com/weather</link>
   <description>Watches, Warnings, Advisories, Discussions</description>
   <pubDate>$pub_date</pubDate>
   <language>en-us</language>
   <generator>jrwx.pl</generator>
   <docs>http://cyber.law.harvard.edu/rss/rss.html</docs>
EORSS1


   if ( $alerts ) {
    foreach my $hash_ref ( @$alerts ) {
        $hash_ref->{'title'} = " " if !$hash_ref->{'title'};
        $rss .= "    <item>\n";
        $rss .= "     <title>$hash_ref->{'title'}</title>\n";
        $rss .= "     <description>$hash_ref->{'title'}</description>\n";
        $rss .= "     <pubDate>$hash_ref->{'pubDate'}</pubDate>\n";
        $rss .= "     <guid>$hash_ref->{'link'}</guid>\n";
        $rss .= "     <link>$hash_ref->{'link'}</link>\n";
        $rss .= "     <author>Cleveland National Weather Service</author>\n";
        $rss .= "    </item>\n";
    }
  }

   if ( $md ) {
    foreach my $hash_ref ( @$md ) {
        $hash_ref->{'title'} = " " if !$hash_ref->{'title'};
        $rss .= "    <item>\n";
        $rss .= "     <title>$hash_ref->{'title'}</title>\n";
        $rss .= "     <description>$hash_ref->{'title'}</description>\n";
        $rss .= "     <pubDate>$hash_ref->{'pubDate'}</pubDate>\n";
        $rss .= "     <guid>$hash_ref->{'link'}</guid>\n";
        $rss .= "     <link>$hash_ref->{'link'}</link>\n";
        $rss .= "     <author>Storm Prediction Center</author>\n";
        $rss .= "    </item>\n";
    }
  }

   if ( $hazards ) {
    foreach my $hash_ref ( @$hazards ) {
        $rss .= "    <item>\n";
        $rss .= "     <title>$hash_ref->{'title'}</title>\n";
        $rss .= "     <description>$hash_ref->{'title'}</description>\n";
#        print "     <pubDate>$hash_ref->{'pubDate'}</pubDate>\n";
        $rss .= "     <pubDate>$pub_date</pubDate>\n";
        $rss .= "     <guid>$hash_ref->{'link'}</guid>\n";
        $rss .= "     <link>$hash_ref->{'link'}</link>\n";
        $rss .= "     <author>Cleveland National Weather Service</author>\n";
        $rss .= "    </item>\n";
    }
  }

    $rss .= "  </channel>\n</rss>\n";

    return $rss;

}

# create date-time stamp as: Thu, 18 Jun 2015 11:41:07 GMT
#           another example: Wed, 02 Oct 2002 13:00:00 GMT
#                          : Wed, 02 Oct 2002 15:00:00 +0200
sub create_date_time_stamp {

    my @month_names = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

    my @day_names   = qw(Sun Mon Tue Wed Thu Fri Sat);

    my $epochsecs = time();

    my ($sec, $min, $hr, $d, $m, $y, $wd)  = (gmtime($epochsecs))[0,1,2,3,4,5,6];

    my $datetime = sprintf "%s, %02d %s %04d %02d:%02d:%02d GMT", $day_names[$wd], $d, $month_names[$m], 2000 + $y-100, $hr, $min, $sec;

   return $datetime;
}

# convert this 2013-06-23T11:52:00-04:00 into: 18 Jun 2015 06:23:45 -0400
# the weekday name will be missing from the resulting string.
# the weekday name appears to be optional in the RSS spec.
# http://www.w3.org/Protocols/rfc822/#z28
sub reformat_nws_date_time {
    my $nws_date_time_str = shift;
    
    if ( !$nws_date_time_str ) {
        return "";
    }

    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

    my @values = split('T', $nws_date_time_str);

    # work on time first
    my @hrminsec = split('-', $values[1]);
    my @time = split(':', $hrminsec[0]);
    my $hr = $time[0];
    my $min = $time[1];
    my $sec = $time[2];

#    my $time_str = sprintf("%02d:%02d:%02d -%s", $hr, $min, $sec, $hrminsec[1]); 
#    my $time_str = sprintf("%02d:%02d:%s -%s", $hr, $min, $sec, $hrminsec[1]); 
    my $time_str = sprintf("%02d:%02d:%s", $hr, $min, $sec);

    # work on date
    my @yrmonday = split('-', $values[0]);
    my $date_str = sprintf("%02d %s %d", $yrmonday[2], $months[$yrmonday[1]-1], $yrmonday[0]);

    return $date_str . " " . $time_str;
}




#############################################


sub parse_alerts_rss {
    my $rss = shift;

    my @msg = get_alerts_from_rss($rss);

    my $len = @msg;

    my $have_something = 0;

    my $str;

    if ( $len ) {
        foreach my $item (@msg) {
            if ( $item->{'link'} and $item->{'title'} ) {
                $str .= "A $item->{'title'}. ";
                $have_something = 1;
            }
        }
    }

    if ( $have_something ) {
        $str = "The following important weather statements exist: " . $str;
        $str .= "Visit toledoweather.info for details."; 
    } else { 
        $str = "No important weather statements exist at this time.";
    } 

    return $str;
}

sub get_alerts_from_rss {
    my $xml = shift;
 
    my @array = ();

    my $feed = XML::FeedPP->new($xml);

    foreach my $item ( $feed->get_item() ) {
        my %hash;
        $hash{'link'}  = $item->link();
        # $hash{'title'} = $item->title();
        $hash{'title'} = $item->title();
        # $hash{'desc'}  = $item->description();
        $hash{'pubDate'}  = $item->pubDate();
        push(@array, \%hash); 
    }
 
    return @array;
}

