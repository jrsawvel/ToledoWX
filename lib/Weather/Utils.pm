package Utils;

use strict;
use Time::Local;
use LWP::Simple;
use HTML::Entities;
use URI::Escape;
use XML::FeedPP;

my $offset = -5;     # EST offset from GMT

# determine if it's daylight savings time for eastern time zone
my $isdst = (localtime)[8];
if ( $isdst ) {
    $offset = -4;
} 

########## public procedures ##########

sub get_formatted_date_time {
    return get_date_time(0,"format");
}

sub get_date_time {
    my $epochsecs = shift;
    my $action = shift;

    my %datetime; #hash

    # return "" if $epochsecs == 0;

    if ( !$epochsecs or !is_numeric($epochsecs) or $epochsecs == 0 ) {
        $epochsecs = time();
    }
   
    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

    # set to Eastern U.S.
    $epochsecs = $epochsecs + ($offset * 3600); 

    my ($mi, $h)    = (gmtime($epochsecs))[1, 2];
   
    my $a="a.m.";
    if ( $h > 11 ) 
    {
        $a = "p.m.";
        if ( $h > 12 ) {
            $h = $h - 12;
        }
    } elsif ( $h == 0 ) {
        $h = 12;
    }

    my ($d, $m, $y) = (gmtime($epochsecs))[3,4,5];


    $datetime{day}  = sprintf "%02d", $d;
    $datetime{mon}  = $months[$m];
    $datetime{year} = sprintf "20%02d", $y-100;
    $datetime{hour} = $h;
    $datetime{min}  = sprintf "%02d", $mi;
    $datetime{ampm} = $a;

    if ( $isdst ) {
        $datetime{tz} = "EDT";
    } else {
        $datetime{tz} = "EST";
    }

    if ( $action and $action eq "format" ) {
#        my $dt = sprintf "%02d-%s-20%02d %d:%02d %s", 
        my $dt = sprintf "%s-%s-%s %s:%s %s %s", $datetime{day}, $datetime{mon}, $datetime{year}, $datetime{hour}, $datetime{min}, $datetime{ampm}, $datetime{tz};
        return $dt;
    } else {
        return \%datetime; #return a reference to the hash
    }
}

sub trim_spaces {
    my $str = shift;

    if ( !defined($str) ) {
        return "";
    }

    # remove leading spaces.   
    $str  =~ s/^\s+//;

    # remove trailing spaces.
    $str  =~ s/\s+$//;

    return $str;
}

sub url_encode {
    my $text = shift;
     
    $text =~ s/([^a-z0-9_.!~*'() -])/sprintf "%%%02X", ord($1)/eig;
    $text =~ tr/ /+/;
    return $text;
}

sub get_time_offset {
    return $offset;
}

sub create_datetime_stamp {
    my $minutes_to_add = shift;

    # creates string for DATETIME field in database as
    # YYYY-MM-DD HH:MM:SS    (24 hour time)
    # Date and time is GMT not local.

    if ( !$minutes_to_add ) {
        $minutes_to_add = 0;
    }

    my $epochsecs = time() + ($minutes_to_add * 60);
    my ($sec, $min, $hr, $mday, $mon, $yr)  = (gmtime($epochsecs))[0,1,2,3,4,5];
    my $datetime = sprintf "%04d-%02d-%02d %02d:%02d:%02d", 2000 + $yr-100, $mon+1, $mday, $hr, $min, $sec;
    return $datetime;
}

sub url_to_link {
    my $str_orig = shift;

    # from Greymatter
    # two lines of code written in part by Neal Coffey (cray@indecisions.org)

    $str_orig =~ s#(^|\s)(\w+://)([A-Za-z0-9?=:\|;,_\-/.%+&'~\#@!\^]+)#$1<a href="$2$3">$2$3</a>#isg;
    $str_orig =~ s#(^|\s)(www.[A-Za-z0-9?=:\|;,_\-/.%+&'~\#@!\^]+)#$1<a href="http://$2">$2</a>#isg;

    # next line a modification from jr to accomadate e-mail links created with anchor tag
    $str_orig =~ s/(^|\s)(\w+\@\w+\.\w+)/<a href="mailto:$2">$1$2<\/a>/isg;

    return $str_orig;
}

sub br_to_newline {
    my $str = shift;

    $str =~ s/<br \/>/\r\n/g;

    return $str;
}

sub remove_html {
    my $str = shift;

    # remove ALL html

     $str =~ s/<([^>])+>|&([^;])+;//gsx;

    return $str;
}

sub newline_to_br {
    my $str = shift;

    $str =~ s/[\r][\n]/<br \/>/g;
    $str =~ s/[\n]/<br \/>/g;

    return $str;
}

sub remove_newline {
    my $str = shift;

#    $str =~ s/[\r][\n]//gs;
#    $str =~ s/\n.*//s;
#    $str =~ s/\s.*//s;

    $str =~ s/\n//gs;
    return $str;
}

sub is_numeric {
    my $str = shift;
    my $rc = 0;

    if ( !defined($str) or !$str ) {
        return 0;
    }
  
    if ( $str =~ m|^[0-9]+$| ) {
        $rc = 1;
    }

    return $rc;
}

sub trim_br {
    my $str = shift;

    # remove leading <br />
    $str =~ s|^(<br />)+||g;

    # remove trailing <br />
    $str =~ s|(<br />)+$||g;

    return $str;
}

sub format_date_time_for_rss {
    my $date = shift;
    my $time = shift;
 
    my %hash = ();
 
    my @short_month_names = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    
    my %months = (Jan => 0, 
                  Feb => 1,
                  Mar => 2,
                  Apr => 3,
                  May => 4,
                  Jun => 5,
                  Jul => 6,
                  Aug => 7,
                  Sep => 8,
                  Oct => 9,
                  Nov => 10,
                  Dec => 11);

    my @dow = qw(Sun Mon Tue Wed Thu Fri Sat);
 
    $time =~ m/(\d+):(\d+):(\d+)/; 
    my $hr  = $1;
    my $min = $2;
    my $sec = $3;

    if ( $time =~ m/pm/i and $hr != 12 ) {
        $hr+=12;    
    }

    $date =~ m/(\w+) (\d+), (\d+)/g;
    my $mon = $months{$1};
    my $day = $2;
    my $year = $3 - 1900;

    my $time_1 = timelocal($sec, $min, $hr, $day, $mon, $year); 

    my ($seconds, $minutes, $hours, $day_of_month, $month_of_year, $current_year, $wday) = (gmtime($time_1))[0,1,2,3,4,5,6];

    # pubDate format: Tue, 04 Oct 2005 12:52:43 Z

    $hash{date} = sprintf "%s, %02d %s %d", $dow[$wday], $day_of_month, $short_month_names[$month_of_year], 1900 + $current_year;

    $hash{time} = sprintf "%02d:%02d:%02d Z", $hours, $minutes, $seconds;

    return %hash;
}

sub quote_string {
    my $str = shift;
    return "NULL" unless defined $str;
    $str =~ s/'/''/g;
    return "'$str'";
}

# links browser does not send the http_referer var to server
sub get_http_referer {
    my $hr = $ENV{HTTP_REFERER};
    if ( !$hr ) {
        $hr = Config::get_value_for("home_page");
    }
    return $hr;
}

# http://usatoday30.usatoday.com/weather/winter/windchill/wind-chill-formulas.htm
# http://en.wikipedia.org/wiki/Wind_chill
# http://search.cpan.org/~jtrammell/Temperature-Windchill-0.04/lib/Temperature/Windchill.pm
# https://github.com/trammell/temperature-windchill
sub get_wind_chill {
    my $tempf   = shift; # Fahrenheit
    my $windmph = shift; # miles per hour

    if ( $tempf > 50 or $windmph < 3 ) {
        return 999;
    }
    
    # 2001 formula : Wind chill temperature = 35.74 + 0.6215T - 35.75V (**0.16) + 0.4275TV(**0.16)
    # V = wind in mph and T = air temp in F degrees
     my $pow = $windmph ** 0.16;
    my $wc = 35.74 + (0.6215 * $tempf) - (35.75 * $pow) + (0.4275 * $tempf * $pow);
    my $rounded = int($wc + $wc/abs($wc*2));
    return $rounded;
}

# http://en.wikipedia.org/wiki/Heat_index#Table_of_Heat_Index_values
# https://code.google.com/p/yweather/issues/detail?id=20
# Calculate Feels Like (given temperature in fahrenheit and humidity)
# source http://en.wikipedia.org/wiki/Heat_index#Formula
sub get_heat_index {
    my $tempf  = shift;
    my $humid = shift;

    # my $unit = $data{'ut'};
    ### convert temperature to Fahrenheit
    # my $tempf = $unit eq 'C' ? $data{'ct'} * 9/5 + 32 : $data{'ct'};
    # my $humid = $data{'ah'};

    my $feels=0;
    my $rounded=0;

    if ( !$tempf or !$humid or !is_numeric($tempf) or !is_numeric($humid) ) {
        return $rounded;
    }

    ### heat index calculation is only useful when temperature > 80F and humidity > 40%
    if ($humid >= 40 && $tempf >= 80) {
        $feels = -42.379 + 2.04901523 * $tempf + 10.14333127 * $humid
            - 0.22475541 * $tempf * $humid - 6.83783 * 10**(-3)*($tempf**(2))
            - 5.481717 * 10**(-2)*($humid**(2))
            + 1.22874 * 10**(-3)*($tempf**(2))*($humid)
            + 8.5282 * 10**(-4)*($tempf)*($humid**(2))
            - 1.99 * 10**(-6)*($tempf**(2))*($humid**(2));

        ### convert back to original unit if necessary
        #if ($unit eq 'C') {
        #    $feels = ($feels - 32) * 5/9;
        #}

        $rounded = int($feels + $feels/abs($feels*2));
    } else {
        ### simply return wind chill
        # $feels = $data{'wc'};
    }
#    return ($feels == int($feels)) ? int($feels) : int($feels + 1);

    return $rounded;
}

sub knots_to_mph {
    my $knots = shift;

    if ( !is_numeric($knots) ) {
        return 0;
    } elsif ( $knots == 0 ) {
        return 0;
    }

    my $mph = 0;

    #  1 Knot = 1.15077945 
    $mph = $knots * 1.15;

    my $rounded = int($mph + $mph/abs($mph*2));

    return $rounded;
}

#  http://www.climate.umn.edu/snow_fence/components/winddirectionanddegreeswithouttable3.htm
#  http://stackoverflow.com/questions/7490660/converting-wind-direction-in-angles-to-text-words
sub wind_direction_degrees_to_cardinal {
    my $degrees = shift;

    my @cardinal_arr = qw(N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW);

    my $val = int(($degrees/22.5)+.5);

    my $idx = $val % 16;

    return $cardinal_arr[$idx];
}

# convert this 2013-06-23T11:52:00-04:00 into a better format
sub reformat_nws_date_time {
    my $nws_date_time_str = shift;
    
    my %hash = ();

    if ( !$nws_date_time_str ) {
        $hash{date} = "-";
        $hash{time} = "-";
        $hash{period} = "-";
        return %hash;
    }

    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

    my @values = split('T', $nws_date_time_str);

    # work on time first
    my @hrminsec = split('-', $values[1]);
    my @time = split(':', $hrminsec[0]);
    my $hr = $time[0];
    my $min = $time[1];

    if ( !is_numeric($hr) ) {
        $hash{date} = "-";
        $hash{time} = "-";
        $hash{period} = "-";
        return %hash;
    }

    my $prd = "am";
    if ( $hr >= 12 ) {
        $prd = "pm";
    }
    if ( $hr > 12 ) {
        $hr = $hr - 12;
    }
    if ( $hr == 0 ) {
        $hr = 12;
    }

    my $time_str = sprintf("%d:%02d", $hr, $min); 

    # work on date
    my @yrmonday = split('-', $values[0]);
    my $date_str = sprintf("%s %d, %d", $months[$yrmonday[1]-1], $yrmonday[2], $yrmonday[0]);

    $hash{date} = $date_str;
    $hash{time} = $time_str;
    $hash{period} = $prd;

    return %hash;
}

# http://stackoverflow.com/questions/77226/how-can-i-capitalize-the-first-letter-of-each-word-in-a-string-in-perl
sub ucfirst_each_word {
    my $str = shift;

    $str =~ s/(\w+)/\u$1/g;

    return $str;
}


# sometimes, need to pull the time from nws messages and not from xml files because it's not listed in an xml file.
# format: 509 am
sub reformat_nws_text_time {
    my $str = shift;
    my $zone = shift;

    my @time = split(' ', $str);

    my $prd = $time[1];  # am or pm

    if ( length($time[0]) == 3 ) {
        $time[0] = "0" . $str;
    }

    my $hr = substr $time[0], 0, 2;

    my $min = substr $time[0], 2, 2;

    if ( $zone and $zone eq "cdt" ) {
        $hr++;
        if ( $hr == 13 ) {
            $hr = 1;
        }
        if ( $hr == 12 and $prd eq "am" ) {
            $prd = "pm";
        } elsif ( $hr == 12 and $prd eq "pm" ) {
            $prd = "am";
        }
    }

    return sprintf "%d:%02d%s", $hr, $min, $prd; 
}



1;

