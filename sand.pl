#!/usr/bin/perl

use strict;

################################################################################
# CONSTANTS
################################################################################
#

$ENV{'TERM'}        = "vt100";
$ENV{'PATH'}        = "/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin";

my $SUCCESS         = 0;
my $ERROR           = 1;

my $STDOFFSET       = "    ";
my $USAGE           = $0 . "\n";
$USAGE              = $USAGE . $STDOFFSET . $STDOFFSET . $STDOFFSET . " --input1  | -i1  < file1 to be compared >\n";
$USAGE              = $USAGE . $STDOFFSET . $STDOFFSET . $STDOFFSET . " --input2  | -i2  < file2 to be compared >\n";
$USAGE              = $USAGE . $STDOFFSET . $STDOFFSET . $STDOFFSET . " --cignore | -ci  < comma separated list of character positions to ignore >\n";
$USAGE              = $USAGE . $STDOFFSET . $STDOFFSET . $STDOFFSET . " --ckeep   | -ck  < comma separated list of character positions to ignore >\n";
$USAGE              = $USAGE . $STDOFFSET . $STDOFFSET . $STDOFFSET . " --rignore | -ri  < comma separated list of record lines to ignore >\n";
$USAGE              = $USAGE . $STDOFFSET . $STDOFFSET . $STDOFFSET . " --rkeep   | -rk  < comma separated list of record lines to ignore >\n";
$USAGE              = $USAGE . $STDOFFSET . $STDOFFSET . $STDOFFSET . " --iregex  | -ir  < regular expression to match and ignore >\n";
$USAGE              = $USAGE . $STDOFFSET . $STDOFFSET . $STDOFFSET . " --kregex  | -kr  < regular expression to match and keep >\n";

#                         --input1  = < file1 to be compared >
#                         --input2  = < file1 to be compared>
#                         --cignore = < character offset to ignore >
#                         --ckeep   = < character offset to keep >
#                         --rignore = < record offset to ignore >
#                         --rkeep   = < record offset to keep >
#                         --iregex  = < regular expression to ignore >
#                         --kregex  = < regular expression to keep >

################################################################################
# VARIABLES
################################################################################
#

my $exit_code           = $SUCCESS;
my $err_msg             = "";
my $command;
my $local_settings      = "$ENV{'HOME'}/.sand";

my $input1;
my $input2;
my $cignore;
my $ckeep;
my $rignore;
my $rkeep;
my $iregex;
my $kregex;

my $key;
my $value;
my $session_id;

my $diff_input1;
my $diff_input2;

my $cignore_input1;
my $cignore_input2;

my $rignore_input1;
my $rignore_input2;

my $regex_input1;
my $regex_input2;

################################################################################
# SUBROUTINES
################################################################################
#

# NAME: f__delta
# A subroutine to execute the cmp command against 2 files.  Any output means the
# two files are different
#
sub f__delta() {
    my $target_file1 = $_[0];
    my $target_file2 = $_[1];
    my $command = "cmp -b \"$target_file1\" \"$target_file2\"";

    open( COMMAND, "$command |" );
    chomp( my $delta = <COMMAND> );
    close( COMMAND );

    return $delta;
}

#
#-------------------------------------------------------------------------------
#

sub f__seqType() {
    my $target_file = $_[0];
    my $seq_type = "line";

    my $command = "wc -l \"$target_file\" | awk '{print \$1}'";

    open( COMMAND, "$command |" );
    chomp( my $line_count = <COMMAND> );
    close( COMMAND );

    if ( $line_count <= 1 ) {
        my $seq_type = "record";
    }

    return $seq_type;
}

#
#-------------------------------------------------------------------------------
#

#---
sub f__rignore() {
    my $input_file           = $_[0];
    my $ignore_range         = $_[1];
    my $output_file_basename = $_[2];
    my $rignore_output              ;

    if (( $input_file ne "" ) && ( $ignore_range ne "" )) {
        # If we were passed in line numbers to ignore, then we need
        # to create $rignore_output without those lines
        my $rignore_output = $output_file_basename . "\.rows";

        my @ranges = split( /,/, $ignore_range );

        # Start iteration for $rignore_output
        my $counter = 1;

        print "INPUT1: $input_file\n";
        print "OUTPUT1: $rignore_output\n";

        open( INPUT, "<", $input_file );
        open( OUTPUT, ">", $rignore_output );
    
        while ( my $line = <INPUT> ) {
            chomp( $line );
            my $flag = 0;
            my $range;

            foreach my $range ( @ranges ) {
                my $min = "";
                my $max = "";
                my $equals = "";

                if ( $range =~ /-/ ) {
                    ( $min, $max ) = split( /-/, $range );
                } else {
                    $equals = $range;
                }

                if ( $equals ne "" ) {

                    if ( $counter != $equals ) {
                        $flag++;
                    }

                } else {

                    if (( $counter < $min ) || ( $counter > $max )) {
                        $flag++;
                    }

                }

            }

            if ( $flag > 0 ) {

                if ( $line !~ /^$counter:/ ) {
                    print OUTPUT "$counter:$line\n";
                } else {
                    print OUTPUT "$line\n";
                }

            }

            $counter++;
        }
    
        close( OUTPUT );
        close( INPUT );
    } else {
        $rignore_output = "";
    }

    return $rignore_output;
}

#
#-------------------------------------------------------------------------------
#

sub f__cignore() {
    my $input_file           = $_[0];
    my $ignore_range         = $_[1];
    my $output_file_basename = $_[2];
    my $cignore_output              ;

    if (( $input_file ne "" ) && ( $ignore_range ne "" )) {
        # If we were passed in column numbers to ignore, then we need
        # to create $diff_input1 and $diff_input2 without those columns
        my $cignore_output = $output_file_basename . "\.rows";

        #awk -F':' '$1 < 105; $1 > 106' /tmp/foo
        #egrep -n "^.*" /tmp/foo | awk -F':' '$1 < 3 ; $1 > 5; $1 > 9' | sort -un

        my @ranges = split( /,/, $ignore_range );

        # Start iteration for $cignore_output
        my $counter = 1;

        open( INPUT, "<", $input_file );
        open( OUTPUT, ">", $cignore_output );
    
        while ( my $line = <INPUT> ) {
            chomp( $line );
            my $range;
            my $newline = "";

            foreach my $range ( @ranges ) {
                my $min = "";
                my $max = "";

                if ( $range =~ /-/ ) {
                    ( $min, $max ) = split( /-/, $range );
                } else {
                    $min = 0;
                    $max = $range;
                }

                my $one_less = $max;
                $one_less--;
                $newline = substr( $line, $min, $one_less );
                $newline = $newline . substr( $line, $max ); 

                if ( $newline !~ /^$counter:/ ) {
                    print OUTPUT "$counter:$newline\n";
                } else {
                    print OUTPUT "$newline\n";
                }

            }

            $counter++;
        }
    
        close( OUTPUT );
        close( INPUT );
    } else {
        $cignore_output = "";
    }

    return $cignore_output;
}

#
#-------------------------------------------------------------------------------
#

sub f__regex() {
    my $input_file           = $_[0];
    my $input_regex          = $_[1];
    my $output_file_basename = $_[2];
    my $regex_mode           = $_[3];
    my $regex_output                ;

    if (( $input_file ne "" ) && ( $input_regex ne "" ) && ( $regex_mode ne "" )) {
        # If we were passed in a regular expression, then we need
        # to create $diff_input1 and $diff_input2 against that regular 
        # expression
        my $regex_output = $output_file_basename . "\.rows";

        #awk -F':' '$1 < 105; $1 > 106' /tmp/foo
        #egrep -n "^.*" /tmp/foo | awk -F':' '$1 < 3 ; $1 > 5; $1 > 9' | sort -un

        my @expressions = split( /,/, $input_regex );

        # Start iteration for $regex_output
        my $counter = 1;

        open( INPUT, "<", $input_file );
        open( OUTPUT, ">", $regex_output );
    
        while ( my $line = <INPUT> ) {
            chomp( $line );
            my $range;
            my $newline  = "";
            my $goodline = "";

            foreach my $expression ( @expressions ) {
                $goodline = "no";

                if ( $line =~ /$expression/ ) {

                    if ( $regex_mode eq "keep" ) {
                        $goodline = "yes";
                    }

                    if ( $regex_mode eq "ignore" ) {
                        $goodline = "no";
                    }

                }

                if ( $goodline eq "yes" ) {

                    if ( $newline !~ /^$counter:/ ) {
                        print OUTPUT "$counter:$newline\n";
                    } else {
                        print OUTPUT "$newline\n";
                    }

                }

            }

            $counter++;
        }
    
        close( OUTPUT );
        close( INPUT );
    } else {
        $regex_output = "";
    }

    return $regex_output;
}

#
#-------------------------------------------------------------------------------
#

################################################################################
# MAIN
################################################################################
#

# WHAT: Setup localized user environment
# WHY:  Cannot proceed otherwise
#
if ( $exit_code == $SUCCESS ) {

    if ( ! -d "$local_settings" ) {
        mkdir "$local_settings";
    }

    $session_id = $$;

#    print "1\n";
}

# WHAT; Gather arguments
# WHY;  Connot proceed without them
#
if ( $exit_code == $SUCCESS ) {

    while ( $ARGV[0] ) {
        chomp( $ARGV[0] );
        $key = $ARGV[0];
        $value = $ARGV[1];

        if (( $key eq "\-\-input1" || $key eq "\-i1" )) {
            $input1 = $value;
        } elsif (( $key eq "\-\-input2" ) || ( $key eq "\-i2" )) {
            $input2 = $value;
        } elsif (( $key eq "\-\-cignore" ) || ( $key eq "\-ci" )) { 
            $cignore = $value;
        } elsif (( $key eq "\-\-ckeep" ) || ( $key eq "\-ck" )) { 
            $ckeep = $value;
        } elsif (( $key eq "\-\-rignore" ) || ( $key eq "\-ri" )) { 
            $rignore = $value;
        } elsif (( $key eq "\-\-rkeep" ) || ( $key eq "\-rk" )) { 
            $rkeep = $value;
        } elsif (( $key eq "\-\-iregex" ) || ( $key eq "\-ir" )) { 
            $iregex = $value;
        } elsif (( $key eq "\-\-kregex" ) || ( $key eq "\-kr" )) { 
            $kregex = $value;
        } else { 
            $err_msg = "Invalid argument \"$ARGV[0]\"";
            $exit_code++;
            last;
        }

        shift @ARGV;
        shift @ARGV;
    }

#    print "2\n";
}

# WHAT: Make sure we are dealing with Line Sequential files
# WHY:  Operations are easier if they are Line Sequential
#
if ( $exit_code == $SUCCESS ) {

    if (( $input1 ne "" ) && ( $input2 ne "" )) {

        foreach my $test_file ( $input1, $input2 ) {

            if ( ! -e "$test_file" ) {
                print "    WARNING:  Could not locate input file \"$test_file\"";
                $err_msg = "Could locate all input files";
                $exit_code++;
            } else {
                my $file_type = &f__seqType($test_file);

                if ( $file_type ne "line" ) {
                    print "    WARNING:  Input File \"$test_file\" may be record sequential.  Please convert it to line sequential using the r2l utility\n";
                    $err_msg = "All input files must be line sequential";
                    $exit_code++;
                }

            }

        }

    } else {
        $err_msg = "Please provide 2 input files for comparison";
        $exit_code++;
    }

}

# WHAT: Use cmp to see if there are any differences
# WHY:  Determines whether or not to continue
#
# TODO: Add in options for skipping characters or lines
if ( $exit_code == $SUCCESS ) {
    my @delta_array = ( $input1, $input2 );
    my $test_delta = &f__delta(@delta_array);

    if ( $test_delta eq "" ) {
        print "No differences detected\n";
        $exit_code = $ERROR;
    }

}
    
# cmp -b file1 file2
#    no ouput == no differences

# WHAT: *S*lice *AND* *D*ice (SAND - get it?)
# WHY:  The reason we are here
#
if ( $exit_code == $SUCCESS ) {
    my $colorscheme = "desert";
    my $html_base    = "/var/www/html";
    my $output_dir = $html_base . "/" . $ENV{'USER'} . "/" . $session_id;

    my $diff_width = 0;

    # Figure out the total width for our diff -y -W command later on
    foreach my $test_file ( $input1, $input2 ) {
        my $command = "head -1 \"$test_file\" | wc -c";

        open( COMMAND, "$command |" );
        chomp( my $this_line_length = <COMMAND> );
        close( COMMAND );

        # Subtract 1 to account for the newline
        $this_line_length--;
        $diff_width += $this_line_length;
    }

    my $session_file = $local_settings . "/session\." . $session_id . "\.diff";

    # Define $diff_input1 and $diff_input2 files to their defaults
    # These may get reassigned later based on other arguments
    $diff_input1 = $input1;
    $diff_input2 = $input2;

    # Generate the left and right side session file names
    my $command = "basename $input1";

    open( COMMAND, "$command |" );
    chomp( my $left_basename = <COMMAND> );
    close( COMMAND );

    my $command = "basename $input2";

    open( COMMAND, "$command |" );
    chomp( my $right_basename = <COMMAND> );
    close( COMMAND );

    my $left_session_file = $local_settings . "/session\." . $session_id . "\." . $left_basename;
    my $right_session_file = $local_settings . "/session\." . $session_id . "\." . $right_basename;

    # Process any rignore directives
    if ( $rignore ne "" ) {
        # Left side
        $diff_input1 = &f__rignore( $diff_input1, $rignore, $left_session_file );

        # Right side
        $diff_input2 = &f__rignore( $diff_input1, $rignore, $right_session_file );
    }

    # Process any cignore directives
    if ( $cignore ne "" ) {
        # Left side
        $diff_input1 = &f__cignore( $diff_input1, $cignore, $left_session_file );

        # Right side
        $diff_input2 = &f__cignore( $diff_input1, $cignore, $right_session_file );
    }

    # Process any iregex directives
    if ( $iregex ne "" ) {
        # If we were passed in a regex to ignore, then we need
        # to create $diff_input1 and $diff_input2 without that regex
        $regex_input1 = $left_session_file . "iregex";
        $regex_input2 = $right_session_file . "iregex";

        # Left side
        $diff_input1 = &f__regex( $diff_input1, $iregex, $regex_input1, "ignore" );

        # Right side
        $diff_input2 = &f__regex( $diff_input1, $iregex, $regex_input2, "ignore" );
    } 

    # Process any iregex directives
    if ( $kregex ne "" ) {
        # If we were passed in a regex to keep, then we need
        # to create $diff_input1 and $diff_input2 without that regex
        $regex_input1 = $left_session_file . "kregex";
        $regex_input2 = $right_session_file . "kregex";

        # Left side
        $diff_input1 = &f__regex( $diff_input1, $iregex, $regex_input1, "keep" );

        # Right side
        $diff_input2 = &f__regex( $diff_input1, $iregex, $regex_input2, "keep" );
    } 

    my $command = "diff -y -W $diff_width \"$diff_input1\" \"$diff_input2\" | egrep \"[\\\|\|\<\|\>]\" > $session_file";
    #print "Command: $command\n";
    system( "$command" );

    if ( -e "$html_base" ) {
        my $command = "host \`hostname\` | egrep \"has address\" | awk '{print \$1}'";
        open( COMMAND, "$command |" );
        chomp( my $host_ip = <COMMAND> );
        close( COMMAND );

        my $url_base;

        if ( $host_ip eq "" ) {
            $url_base = "file://";
        } else {
            $url_base = "http://" . $host_ip;
        }

        my $url = $url_base . $output_dir;

        if ( ! -d "$output_dir" ) {
            my $command = "mkdir -p \"$output_dir\"";
            system( "$command" );
        }

        # Build $left_session_file
        my $command = "awk -F':' '{print \$1}' $session_file";

        open( COMMAND, "$command |" );
        chomp( my @line_numbers = <COMMAND> );
        close( COMMAND );

        open( INPUT, "<", $diff_input1 );
        open( OUTPUT, ">", $left_session_file );
    
        while ( my $line = <INPUT> ) {
            chomp( $line );

            foreach my $line_number ( @line_numbers ) {

                if ( $line =~ /^$line_number:/ ) {
                    print OUTPUT "$line\n";
                }

            }

        }

        close( INPUT );
        close( OUTPUT );

        # Build $right_session_file
        my $command = "awk -F'[\\\||<|>]' '{print \$NF}' $session_file | awk -F':' '{print \$1}' | awk '{print \$1}'";

        open( COMMAND, "$command |" );
        chomp( my @line_numbers = <COMMAND> );
        close( COMMAND );

        open( INPUT, "<", $diff_input2 );
        open( OUTPUT, ">", $right_session_file );
    
        while ( my $line = <INPUT> ) {
            chomp( $line );

            foreach my $line_number ( @line_numbers ) {

                if ( $line =~ /^$line_number:/ ) {
                    print OUTPUT "$line\n";
                }

            }

        }

        close( INPUT );
        close( OUTPUT );

        my $command = "vimdiff \"$left_session_file\" \"$right_session_file\" -c ':colorscheme $colorscheme' +TOhtml '+w! $output_dir/index.html' '+qall!' > /dev/null 2>\&1";
        print "    Creating vimdif results: $url/index.html\n";
        system( "$command" );

        # Make temp files in $local_settings dir:
        # compute line length in each file
        #    head -1 file | wc -c
        # add them together for the -W value to diff
        #     diff -y -W <line width> file1 file2 | egrep [\||<|>]
        # Save that to temp file
        # Split each line out of temp into 2 parts, determine line number, save as files
        # then vimdiff them
    }

}

# WHAT: Complain if necessary and exit
# WHY:  Success or failure, either way we are through!
#
if ( $exit_code != $SUCCESS ) {

    if ( $err_msg ne "" ) {
        print "\n    ERROR:  $err_msg ... processing halted\n";
        print "\n    Usage:  $USAGE\n";
    }

}

exit $exit_code;
