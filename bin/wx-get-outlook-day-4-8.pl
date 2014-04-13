#!/usr/bin/perl -wT

# wx-get-outlook-html.pl - download SPC convective outlook html pages 

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledotk/ToledoWX/lib";
}

use Weather::Web;
    
my $dt = Utils::get_formatted_date_time(); 

my $htmldir = Config::get_value_for("htmldir");

    my $configparam = "day48outlookhtml";
    my $dayurl      = Config::get_value_for($configparam);
    my $dayfilename = $htmldir . "day48otlk.html";

    # check to satisfy taint mode.
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
        my $html_output = Web::display_page("Day 4-8 Convective Outlook", "returnoutput");

        open FILE, ">$dayfilename" or die "Can't create file.\n";
        print FILE $html_output;
        close FILE;
    } else {
        print STDERR "file not downloaded. $response->status_line \n";
        # die $response->status_line . "\n";
    }


    my $imagedir = Config::get_value_for("imagedir");

    download_gif("day48prob.gif", $imagedir, "die");



sub download_gif {
    my $gif_file = shift;
    my $imagedir = shift;
    my $error_out = shift;

    my $spc_gif_url = Config::get_value_for("day48outlookgif");

    my $dayfilename = $imagedir . $gif_file;
    if ( $dayfilename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $dayfilename = $1;
    } else {
        die "$dt : Bad filename $dayfilename."; 
    }

    my $gif_ua = LWP::UserAgent->new;
    my $gif_request = HTTP::Request->new( GET => $spc_gif_url);
    my $gif_response = $gif_ua->request($gif_request);
    if ($gif_response->is_success) {
        my $gif_content = $gif_response->content;
        open FILE, ">$dayfilename" or die "Can't create file.\n";
        binmode FILE;
        print FILE $gif_content;
        close FILE;
    } elsif ( $error_out and $error_out eq "die" ) {
        print STDERR "file not downloaded.\n";
    }
}
