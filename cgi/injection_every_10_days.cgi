#!/usr/bin/perl

    use strict;
    use warnings;

    use POSIX qw( strftime );

print "Content-type: text/html\n\n";

print <DATA>;



my $row_width = 10;

my ($last_year, $last_month) = ('', '');
my ($year_needs_printed, $month_needs_printed);

my $starting_day = time();
$starting_day -= 4 * 86400;     # start four days early, to allow space to print the month and year
$starting_day -= 10 * 30.5 * 86400;     # start four days early, to allow space to print the month and year
$starting_day += 21 * 86400;     # start four days early, to allow space to print the month and year

for (my $day_offset=0; $day_offset < 80 * $row_width;  $day_offset++) {
                                   # ^^  number of rows to print

    my ($year, $month, $day) = split ' ',
                                  strftime "%Y %b %e", localtime($starting_day + $day_offset * 86400);
    $month = uc $month;

    #print "$year -- $month -- $day\n";
    my $col = $day_offset % $row_width;
    if ($col == 0) {
        print "\n<tr>";
    }

    ($last_year ne $year) && $year_needs_printed++;
    ($last_month ne $month) && $month_needs_printed++;
    $last_year = $year;
    $last_month = $month;

    #$year_needs_printed++ if ($col == 8);       # DEBUG only

    if ($year_needs_printed && $col <= $row_width - 2) {
        # we can only print the year if we have two columns left at the end
        print "<td class=grayright><div><div><center>$year</center></div></div> <td>";
        $year_needs_printed = 0;
        $day_offset++;      # skip one column
        next;
    }

    if ($month_needs_printed && $col <= $row_width - 2) {
        # we can only print the month if we have two columns left at the end
        print "<td class=grayright><div><div><center>$month</center></div></div> <td>";
        $month_needs_printed = 0;
        $day_offset++;      # skip one column
        next;
    }

    print "<td>$day";
}

print "\n</table>\n";



__DATA__

<style>

    /* --==##  simple spacer  ##==-- */
    ins {margin-left:3em; text-decoration:none}
                    /* ^^ abuses the <ins> tag, uses it for something else entirely */

    /* --==##  default to sans-serif font  ##==-- */
                    /* but when printing, use the default serif */
    body, td {font-family: sans-serif}
    @media print { body, td {font-family: serif} }

    /* --==##  links aren't underlined unless you :hover  ##==-- */
    a:link:hover {text-decoration:underline; background-color:#aaf; color:#000!important}
    a:visited:hover {background-color:#faf; color:#000!important}
    a {text-decoration:none}
    @media print { a {text-decoration:underline} }

    /* --==##  make h1/h2/h3 stand out with bars  ##==-- */
    h1, h2, h3 {padding:0.3em; border-top:2px solid #000; border-bottom:2px solid #000;
    background-color:#ccc; margin-top:2em}
    body>h1:first-child, body>h2:first-child, body>h3:first-child {margin-top:0}

    /* --==##  table cells have a nice border  ##==-- */
    table.wikitable {border-collapse:collapse}
    table.wikitable td, table.wikitable th {border:1px solid #aaa; padding:0.3em}
    table.wikitable th {background-color:#000; color:#fff}
    table.wikitable th a {color:#aaf}
    table.wikitable th a:visited {color:#faf}
    table.wikitable tr.header td, table.wikitable thead td {border:#fff}

    /* --==##  kbd has gray background  ##==-- */
    kbd {background-color:#bbb}

    /* --==##  selectively make ul/ol spaced (non-cascading)  ##==-- */
    ul.spaced > li, ol.spaced > li {margin-bottom:1em}
    .spaced > li > .spaced {margin-top:1em}

    /* --==##  CSS reset  ##==-- */
    a img {border:0}

    /* --==##  text is grayed-out for digressions  ##==-- */
    .digression     {color:#aaa}
    span.digression {margin-left:2em}
    .digression     a {color:#aaf}
    .digression     a:visited {color:#e9e}

    /* BODY option -- make ul/ol be half-spaced */
    ul.halfspaced > li, ol.halfspaced > li, body.halfspaced li {margin-bottom:0.5em}
    .halfspaced > li > .halfspaced, body.halfspaced li > ul, body.halfspaced li > ol {margin-top:0.5em}
</style>

<style>
    table {font-size:60%}
    td, th {text-align:center; border:1px solid #000!important; padding:0.2em!important}
    td > div {position:relative; left:0; top:-0.55em; width:0; height:0}      /* divs will float outside the normal document flow */
    td > div > div {width:2.8em; height:1em; /* border:1px solid red!important */ }
    td.grayright {border-right:1px solid #888!important}      /* make the border on the right-side gray */
</style>


<table class="wikitable">

<tr><td colspan=10 style="border-left:hidden!important; border-top:hidden!important;
                border-right:hidden!important; font-size:120%">
        <center><b>every 10 days
