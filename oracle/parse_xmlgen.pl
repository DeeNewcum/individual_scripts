#!/usr/bin/perl

# Parse the output of Oracle's dbms_xmlgen.getxml(),
# and reformat into properly-formatted text columns.
# (ie. do what sqlplus should have done in the first place).

    use strict;
    use warnings;

    use CGI;
    use Data::Dumper;

my $xml = join("", <DATA>);
parse_xmlgen($xml);

sub parse_xmlgen {
    my ($xml_output) = @_;
    my @rows = ($xml_output =~ m#<row>(.*?)</row>#sig);
    #die Dumper \@rows;

    my @rows_out;
    foreach my $row (@rows) {
        my %row;
        while ($row =~ m#<([^>]*)>(.*?)</.*?>#sig) {
            my ($field, $value) = ($1, $2);
            $field = CGI::unescapeHTML($field);
            $value = CGI::unescapeHTML($value);
            $row{$field} = $value;
        }
        #die Dumper \%row;
        push @rows_out, \%row;
    }
    print Dumper \@rows_out;
    
}


__DATA__
<?xml version="1.0"?>
<ROWSET>
 <ROW>
  <EMPLOYEE_ID>100</EMPLOYEE_ID>
  <FIRST_NAME>Steven</FIRST_NAME>
  <LAST_NAME>King</LAST_NAME>
  <PHONE_NUMBER>515.123.4567</PHONE_NUMBER>
 </ROW>
 <ROW>
  <EMPLOYEE_ID>101</EMPLOYEE_ID>
  <FIRST_NAME>Neena</FIRST_NAME>
  <LAST_NAME>Kochhar</LAST_NAME>
  <PHONE_NUMBER>515.123.4568</PHONE_NUMBER>
 </ROW>
 <ROW>
  <EMPLOYEE_ID>102</EMPLOYEE_ID>
  <FIRST_NAME>Lex</FIRST_NAME>
  <LAST_NAME>De Haan</LAST_NAME>
  <PHONE_NUMBER>515.123.4569</PHONE_NUMBER>
 </ROW>
 <ROW>
  <EMPLOYEE_ID>103</EMPLOYEE_ID>
  <FIRST_NAME>Alexander</FIRST_NAME>
  <LAST_NAME>Hunold</LAST_NAME>
  <PHONE_NUMBER>590.423.4567</PHONE_NUMBER>
 </ROW>
 <ROW>
  <EMPLOYEE_ID>104</EMPLOYEE_ID>
  <FIRST_NAME>Bruce</FIRST_NAME>
  <LAST_NAME>Ernst</LAST_NAME>
  <PHONE_NUMBER>590.423.4568</PHONE_NUMBER>
 </ROW>
</ROWSET>
