package Web;

use strict;

# use Time::Local;

$CGI::HEADERS_ONCE=1;

use HTML::Template;
use XML::TreePP;
use LWP::Simple;
use LWP::UserAgent;

use Weather::Utils;
use Weather::Config;

my $wx_th              = Config::get_value_for("template_home");
$ENV{HTML_TEMPLATE_ROOT}    = $wx_th;
my $kestrel_template        = "";

my @http_header = ("Content-type: text/html;\n\n", "");
my $http_header_var = 0;


sub display_page {
    my $function = shift;
    my $output_type = shift;

    my $dt = Utils::get_date_time(time());
    my $datetimestr = "$dt->{mon} $dt->{day}, $dt->{year} - $dt->{hour}:$dt->{min} $dt->{ampm} $dt->{tz}";

# creating static html pages so don't need this    
# print $http_header[$http_header_var]; 

    my $site_name       =  Config::get_value_for("site_name");

    set_template_variable("pagetitle",          "$function - $site_name");
    set_template_variable("home_page",          Config::get_value_for("home_page"));
    set_template_variable("site_name",          $site_name);
    set_template_variable("cssurl",             Config::get_value_for("cssurl"));  

    set_template_variable("pagecreateddate",   $datetimestr);
    # set_template_variable("requesturi",       $ENV{REQUEST_URI});

    if ( $output_type and $output_type eq "returnoutput" ) {
        return $kestrel_template->output;
    } 

    print $kestrel_template->output;
    exit;
}

sub set_template_name {
    my $template_name = shift;
    $kestrel_template = HTML::Template->new(filename => "$wx_th/$template_name.tmpl");
}

sub set_template_loop_data {
    my $loop_name     = shift;
    my $loop_data     = shift; 
    $kestrel_template->param("$loop_name" . "_loop" => $loop_data);
}

sub set_template_variable {
    my $var_name   = shift;
    my $var_value  = shift;
    $kestrel_template->param("$var_name"  =>   $var_value); 
}

sub print_template {
    my $content_type = shift;
    print $content_type . "\n\n";
    print $kestrel_template->output;
    exit;
}

sub report_error
{
    my $type   = shift;
    my $cusmsg = shift;
    my $sysmsg = shift;

    set_template_name("$type" . "error");
    set_template_variable("cusmsg", "$cusmsg");

    if ( $type eq "user" ) { 
        set_template_variable("sysmsg", "$sysmsg");
    } elsif ( ($type eq "system") and Config::get_value_for("debug_mode") ) {
        set_template_variable("sysmsg", "$sysmsg");
    }
    set_template_variable("referer", Utils::get_http_referer()); 
    display_page("Error");
    exit;
}

1;
