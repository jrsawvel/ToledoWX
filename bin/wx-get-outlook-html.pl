#!/usr/bin/perl -wT

# wx-get-outlook-html.pl - download SPC convective outlook html pages 

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledoweather/ToledoWX/lib";
}

use Weather::Web;
    
my $dt = Utils::get_formatted_date_time(); 

my $htmldir = Config::get_value_for("htmldir");

for (my $ctr=1; $ctr < 4; $ctr++) {
    my $configparam = "day" . $ctr . "outlookhtml";
    my $dayurl  = Config::get_value_for($configparam);
    my $dayfilename="";

    if ( $dayurl =~ m /^.*[\/](.*)$/ ) {
        $dayfilename = $htmldir . $1;
    } else {
        die "cannot obtain file name from $dayurl.\n";
    }

    if ( $dayfilename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $dayfilename = $1;
    } else {
        die "$dt : Bad data in first argument";	
    }

    my $ua = LWP::UserAgent->new;
    # $ua->timeout(180) # default is 180 secs or 3 mins

    my $request = HTTP::Request->new( GET => $dayurl );

    my $response = $ua->request($request);

    if ($response->is_success) {
        my $content = $response->content;

        my $text ="";

        if ( $content =~ m/<pre>(.*)<\/pre>/is ) {
            $text = $1;
        } else {
            die "unable to parse html file for $configparam.\n";
        }        
 
        $text = Utils::remove_html($text);
        $text = Utils::trim_spaces($text);
        $text = Utils::newline_to_br($text);
        $text = lc($text);

        Web::set_template_name("convectiveoutlook");
        Web::set_template_variable("text", $text);
        Web::set_template_variable("back_and_home", 1);
        Web::set_template_variable("back_button_url", Config::get_value_for("outlook_home_page")); 
        my $html_output = Web::display_page("Day $ctr Convective Outlook", "returnoutput");

        open FILE, ">$dayfilename" or die "Can't create file.\n";
        print FILE $html_output;
        close FILE;
    } else {
        print STDERR "file not downloaded. $response->status_line \n";
        # die $response->status_line . "\n";
    }
}

