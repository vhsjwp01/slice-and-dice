#!/usr/bin/perl

use strict;

################################################################################
# CONSTANTS
################################################################################

$ENV{'TERM'}        = "vt100";
$ENV{'PATH'}        = "/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin";

my $SUCCESS         = 0;
my $ERROR           = 1;

my $USAGE           = "$0 < RSEQ file to be converted to LSEG > < record length >";

################################################################################
# VARIABLES
################################################################################

my $exit_code       = $SUCCESS;
my $err_msg         = "";
my $command;
my $local_settings  = "$ENV{'HOME'}/.r2l";

################################################################################
# SUBROUTINES
################################################################################

################################################################################
# MAIN
################################################################################

# WHAT: Setup localized user environment
# WHY:  Cannot proceed otherwise
#
if ( $exit_code == $SUCCESS ) {

    if ( ! -d "$local_settings" ) {
        mkdir "$local_settings";
    }

}

# WHAT: Make sure both arguments are present
# WHY:  Connot proceed without them
#
if ( $exit_code == $SUCCESS ) {

    if (( $ARGV[0] ne "" ) && ( $ARGV[1] ne "" )) {
        my $input_file = $ARGV[0];
        my $numeral_test1 = $ARGV[1];
        my $record_length = $numeral_test1;
        $numeral_test1 =~ s/[^0-9]//g;
    
        # Make sure $record_length is an integer"
        if ( "$numeral_test1" eq "$record_length" ) {
    
            if ( -e "$input_file" ) {
                my $byte_count = (stat($input_file))[7];
                my $iteration_modulo = $byte_count % $record_length;
                $command = "wc -l \"$input_file\" | awk '{print \$1}'";
    
                open( COMMAND, "$command |" );
                chomp( my $line_count = <COMMAND> );
                close( COMMAND );
    
                if (( $byte_count >= $record_length ) && ( ${line_count} <= 1 )) {
                    print "Record sequential file detected\n";
    
                    if ( $iteration_modulo == 0 ) {
                        # Start loop to create line sequential file
                        my $line;
                        my $output_file = ( split '/', $input_file )[ -1 ];
                        my $output_file = "./$output_file.lseq";
                        $| = 1;
                        print "    Creating Line Sequential file: $output_file ... ";
                        $| = 0;
    
                        my $counter = 1;

                        open( INPUT, "<", $input_file );
                        open( OUTPUT, ">", $output_file );
    
                        while ( read( INPUT, $line, $record_length )) {
                            chomp( $line );

                            if ( $ARGV[2] eq "--lines" ) {
                                print OUTPUT "\[line-$counter\]\ $line\n";
                            } else {
                                print OUTPUT "$line\n";
                            }

                            $counter++;
                        }
    
                        close( OUTPUT );
                        close( INPUT );
    
                        print "DONE\n";
                    } else { 
                        $err_msg = "Record length \"$record_length\" does not produce records of consistent length";
                        $exit_code = $ERROR;
                    }
    
                } else { 
                    $err_msg = "File \"$input_file\" is already line sequential";
                    $exit_code = $ERROR;
                } 
       
            } else {
                $err_msg = "Please provide an input file";
                $exit_code = $ERROR;
            }
    
        } else {
            $err_msg = "Please provide the record byte count";
            $exit_code = $ERROR;
        }
    
    } else {
        $err_msg = "Not enough command line arguments were provided";
        $exit_code = $ERROR;
    }

}

# WHAT: Complain if necessary and exit
# WHY:  Success or failure, either way we are through!
#
if ( $exit_code != $SUCCESS ) {

    if ( $err_msg ne "" ) {
        print "\n";
        print "    ERROR:  $err_msg ... processing halted\n";
        print "\n";
        print "    Usage:  $USAGE\n";
    }

}

exit $exit_code;
