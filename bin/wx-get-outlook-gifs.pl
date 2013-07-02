#!/usr/bin/perl -wT

# wx-get-outlook-gifs.pl - download SPC convective outlook gifs

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledotk/Weather/lib";
}

use Weather::Web;
    
my $dt = Utils::get_formatted_date_time(); # returns format: 24-June-2013 12:23 p.m. EDT

my $filename =  Config::get_value_for("htmldir") . Config::get_value_for("wx_outlook_home_output_file");
if ( $filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $filename = $1;
} else {
    die "$dt : Bad filename $filename."; 
}

my $imagedir = Config::get_value_for("imagedir");

my %gif_file_hash = ();
my %prob_gif_file_hash = ();

for (my $ctr=1; $ctr < 4; $ctr++) {
    my $configparam = "day" . $ctr . "outlookhtml";
    my $dayurl  = Config::get_value_for($configparam);

    my $ua = LWP::UserAgent->new;
    my $request = HTTP::Request->new( GET => $dayurl );
    my $response = $ua->request($request);
    if ($response->is_success) {
        my $content = $response->content;

        my $time_gif = "";

        my $gif_file = "";
        my $srch = "<a href=\"day" . $ctr . "otlk_(.*)_prt.html\">";
        if ( $content =~ m/$srch/si ) {
            $time_gif = $1;
            $gif_file = "day" . $ctr . "otlk_" . $time_gif . ".gif";
        } else {
            die "unable to parse html file for $configparam.\n";
        }        

        $gif_file_hash{"day" . $ctr} = $gif_file;

        download_gif($gif_file, "die");

        if ( $ctr == 1 ) {
            # download day 1 gifs for hail, wind, and tornado probibilities
            $prob_gif_file_hash{tornado} = "day1probotlk_" . $time_gif . "_torn.gif";
            $prob_gif_file_hash{wind}    = "day1probotlk_" . $time_gif . "_wind.gif";
            $prob_gif_file_hash{hail}    = "day1probotlk_" . $time_gif . "_hail.gif";

            download_gif($prob_gif_file_hash{tornado});
            download_gif($prob_gif_file_hash{wind});
            download_gif($prob_gif_file_hash{hail});
        }
    } 
    else {
        die $response->status_line;
    }
}

Web::set_template_name("outlookhome");
Web::set_template_variable("imagehome", Config::get_value_for("imagehome"));
Web::set_template_variable("wxhome",    Config::get_value_for("wxhome"));

Web::set_template_variable("day1gif", $gif_file_hash{day1});
Web::set_template_variable("day2gif", $gif_file_hash{day2});
Web::set_template_variable("day3gif", $gif_file_hash{day3});

Web::set_template_variable("day1tornadogif", $prob_gif_file_hash{tornado});
Web::set_template_variable("day1windgif",    $prob_gif_file_hash{wind});
Web::set_template_variable("day1hailgif",    $prob_gif_file_hash{hail});

my $html_output = Web::display_page("Convective Outlook Home", "returnoutput");
open FILE, ">$filename" or die "$dt : could not create file $filename";
print FILE $html_output;
close FILE;



sub download_gif {
    my $gif_file = shift;
    my $error_out = shift;

    my $spc_gif_url = Config::get_value_for("spcoutlookgifhome") . "/" . $gif_file; 

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
