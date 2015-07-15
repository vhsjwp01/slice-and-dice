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
$USAGE              = $USAGE . $STDOFFSET . $STDOFFSET . $STDOFFSET . " --ckeep   | -ck  < comma separated list of character positions to keep >\n";
$USAGE              = $USAGE . $STDOFFSET . $STDOFFSET . $STDOFFSET . " --rignore | -ri  < comma separated list of record lines to ignore >\n";
$USAGE              = $USAGE . $STDOFFSET . $STDOFFSET . $STDOFFSET . " --rkeep   | -rk  < comma separated list of record lines to keep >\n";
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

sub f__rows() {
    my $input_file           = $_[0];
    my $input_range          = $_[1];
    my $output_file_basename = $_[2];
    my $row_mode             = $_[3];
    my $row_output                  ;
    my $row_ext                     ;

    if (( $input_file ne "" ) && ( $input_range ne "" )) {
        # If we were passed in line numbers to ignore, then we need
        # to create $row_output without those lines
        print "Processing row $row_mode directives\n";

        if ( $row_mode eq "keep" ) {
            $row_ext = "\.krows";
        }

        if ( $row_mode eq "ignore" ) {
            $row_ext = "\.irows";
        }

        #print "Column EXT: $row_ext\n";

        $row_output = $output_file_basename . $row_ext;
        #print "Row Output: $row_output\n";

        my @ranges = split( /,/, $input_range );

        # Start iteration for $row_output
        my $counter = 1;

        print "INPUT: $input_file\n";
        print "OUTPUT: $row_output\n";

        open( INPUT, "<", $input_file );
        open( OUTPUT, ">", $row_output );
    
        while ( my $line = <INPUT> ) {
            chomp( $line );
            #print "raw line is: $line\n";
            my $flag = 0;
            my $range;
            my $goodline = "no";
            my $line_number_string = "";
            my @discard;

            if ( $line =~ /^\[line-\d+\]\ / ) {
                ( $line_number_string, @discard ) = split( /\ /, $line ); 
                $line =~ s/^\[line-\d+\]\ //g;
                $counter = $line_number_string;
                $counter =~ s/[^0-9]//g;
            }

            foreach my $range ( @ranges ) {
                my $min              = "";
                my $max              = "";
                my $delta            = "";
                my $this_line_number = "";

                if ( $range =~ /-/ ) {
                    ( $min, $max ) = split( /-/, $range );
                    #print "\n\nRange is: $min - $max\n\n";

                    if ( $max ne "" ) {
                        $delta = $max - $min;

                        if (( $max <= 0 ) || ( $min <= 0 ) || ( $delta <= 0 )) {
                            print "    ERROR:  Invalid row range detected ... processing halted\n";
                            exit 1;
                        }

                    }

                } else {
                    $this_line_number = $range;
                }

                if ( $row_mode eq "ignore" ) {

                    if ( $this_line_number ne "" ) {

                        if ( $counter != $this_line_number ) {
                            $goodline = "yes";
                        }

                    } else {

                        if (( $counter < $min ) || ( $counter > $max )) {
                            $goodline = "yes";
                        }

                    }

                }

                if ( $row_mode eq "keep" ) {
                    #print "Counter is: $counter\n";

                    if ( $this_line_number ne "" ) {
                        #print "Good Line Number is: $this_line_number\n";

                        if ( $counter == $this_line_number ) {
                            #print "Found one good line\n";
                            $goodline = "yes";
                        }

                    } else {
                        #print "Min is: $min\n";
                        #print "Max is: $max\n";

                        if (( $counter >= $min ) && ( $counter <= $max )) {
                            #print "Found good line $counter between $min and $max\n";
                            $goodline = "yes";
                        }

                    }

                }

            }

            if ( $goodline eq "yes" ) {
                #print "Found good line: $line\n";

                if ( $line !~ /^\[line-\d+\]\ / ) {

                    if ( $line_number_string ne "" ) {
                        print OUTPUT "$line_number_string $line\n";
                    } else {
                        print OUTPUT "\[line-$counter\]\ $line\n";
                    }

                } else {
                    print OUTPUT "$line\n";
                }

            }

            $counter++;
        }
    
        close( OUTPUT );
        close( INPUT );
    } else {
        $row_output = "";
    }

    return $row_output;
}

#
#-------------------------------------------------------------------------------
#

sub f__columns() {
    my $input_file           = $_[0];
    my $input_range          = $_[1];
    my $output_file_basename = $_[2];
    my $column_mode          = $_[3];
    my $column_output               ;
    my $column_ext                  ;

    if (( $input_file ne "" ) && ( $input_range ne "" ) && ( $column_mode ne "" )) {
        # If we were passed in column numbers to process, then we need
        # to create $diff_input1 and $diff_input2 based on those columns

        print "Processing column $column_mode directives\n";

        if ( $column_mode eq "keep" ) {
            $column_ext = "\.kcols";
        }

        if ( $column_mode eq "ignore" ) {
            $column_ext = "\.icols";
        }

        #print "Column EXT: $column_ext\n";

        $column_output = $output_file_basename . $column_ext;
        #print "Column Output: $column_output\n";

        #awk -F':' '$1 < 105; $1 > 106' /tmp/foo
        #egrep -n "^.*" /tmp/foo | awk -F':' '$1 < 3 ; $1 > 5; $1 > 9' | sort -un

        my @ranges = split( /,/, $input_range );

        # Start iteration for $column_output
        my $counter = 1;

        open( INPUT, "<", $input_file );
        open( OUTPUT, ">", $column_output );
    
        while ( my $line = <INPUT> ) {
            chomp( $line );
            my $range;
            my $newline = "";
            my $line_number_string = "";
            my @discard;

            if ( $line =~ /^\[line-\d+\]\ / ) {
                ( $line_number_string, @discard ) = split( /\ /, $line ); 
                $line =~ s/^\[line-\d+\]\ //g;
                $counter = $line_number_string;
                $counter =~ s/[^0-9]//g;
            } else {
                $line_number_string = "";
            }

            foreach my $range ( @ranges ) {
                my $start = "";
                my $end   = "";
                my $delta = "";

                if ( $range =~ /-/ ) {
                    ( $start, $end ) = split( /-/, $range );
                } else {
                    $start = $range;
                }

                if ( $end ne "" ) {
                    $delta = $end - $start;

                    if (( $start <= 0 ) || ( $end <= 0 ) || ( $delta <= 0 )) {
                        print "    ERROR:  Invalid column range detected ... processing halted\n";
                        exit 1;
                    }

                } else {
                    $delta = 1;
                }

                # Compensate for zero based indexing
                $start--;

                if ( $start < 0 ) {
                    $start = 0;
                }

                if ( $column_mode eq "keep" ) {
                    $newline = $newline . substr( $line, $start, $delta );
                }

                if ( $column_mode eq "ignore" ) {

                    if ( $start > 0 ) {
                        $newline = $newline . substr( $line, 0, $start );
                    }

                    $newline = $newline . substr( $line, $delta );
                }

            }

            if ( $newline ne "" ) {
                #print "Newline is: $newline\n";

                if ( $newline !~ /^\[line-\d+\]\ / ) {

                    if ( $line_number_string ne "" ) {
                        print OUTPUT "$line_number_string $newline\n";
                    } else {
                        print OUTPUT "\[line-$counter\]\ $newline\n";
                    }

                } else {
                    print OUTPUT "$newline\n";
                }

            }

            $counter++;
        }
    
        close( OUTPUT );
        close( INPUT );
    } else {
        $column_output = "";
    }

    return $column_output;
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
    my $regex_ext                   ;

    if (( $input_file ne "" ) && ( $input_regex ne "" ) && ( $regex_mode ne "" )) {

        # If we were passed in a regular expression, then we need
        # to create $diff_input1 and $diff_input2 against that regular 
        # expression

        if ( $regex_mode eq "keep" ) {
            $regex_ext = "\.kregex";
        }

        if ( $regex_mode eq "ignore" ) {
            $regex_ext = "\.iregex";
        }

        $regex_output = $output_file_basename . $regex_ext;

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
            my $line_number_string = "";
            my @discard;

            if ( $line =~ /^\[line-\d+\]\ / ) {
                ( $line_number_string, @discard ) = split( /\ /, $line ); 
                $line =~ s/^\[line-\d+\]\ //g;
                $counter = $line_number_string;
                $counter =~ s/[^0-9]//g;
            } else {
                $line_number_string = "";
            }

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

                    if ( $line !~ /^\[line-\d+\]\ / ) {

                        if ( $line_number_string ne "" ) {
                            print OUTPUT "$line_number_string $line\n";
                        } else {
                            print OUTPUT "\[line-$counter\]\ $line\n";
                        }

                    } else {
                        print OUTPUT "$line\n";
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
                #print "Detected filetype: $file_type\n";

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
    
# cm#p -b file1 file2
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
        my $command = "head -1 \"$test_file\" 2> /dev/null | wc -c";

        open( COMMAND, "$command |" );
        chomp( my $this_line_length = <COMMAND> );
        close( COMMAND );

        # Subtract 1 to account for the newline
        $this_line_length--;
        $diff_width += $this_line_length;
    }

    #print "Detected DIFF width: $diff_width\n";

    if ( $diff_width <= 0 ) {
        print "    WARNING:  One or both input files may be record sequential.  Please convert all input files to line sequential using the r2l utility\n";
        $err_msg = "All input files must be line sequential";
        $exit_code++;
    } else {
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
            $diff_input1 = &f__rows( $diff_input1, $rignore, $left_session_file, "ignore" );

            # Right side
            $diff_input2 = &f__rows( $diff_input2, $rignore, $right_session_file, "ignore" );
        }

        # Process any rkeep directives
        if ( $rkeep ne "" ) {
            # Left side
            $diff_input1 = &f__rows( $diff_input1, $rkeep, $left_session_file, "keep" );

            # Right side
            $diff_input2 = &f__rows( $diff_input2, $rkeep, $right_session_file, "keep" );
        }

        # Process any cignore directives
        if ( $cignore ne "" ) {
            # Left side
            $diff_input1 = &f__columns( $diff_input1, $cignore, $left_session_file, "ignore" );

            # Right side
            $diff_input2 = &f__columns( $diff_input2, $cignore, $right_session_file, "ignore" );
        }

        # Process any ckeep directives
        if ( $ckeep ne "" ) {
            # Left side
            print "Diff input1: $diff_input1\n";
            $diff_input1 = &f__columns( $diff_input1, $ckeep, $left_session_file, "keep" );
            print "Diff input1: $diff_input1\n";

            # Right side
            print "Diff input2: $diff_input2\n";
            $diff_input2 = &f__columns( $diff_input2, $ckeep, $right_session_file, "keep" );
            print "Diff input2: $diff_input2\n";
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
            $diff_input2 = &f__regex( $diff_input2, $iregex, $regex_input2, "ignore" );
        } 

        # Process any kregex directives
        if ( $kregex ne "" ) {
            # If we were passed in a regex to keep, then we need
            # to create $diff_input1 and $diff_input2 without that regex
            $regex_input1 = $left_session_file . "kregex";
            $regex_input2 = $right_session_file . "kregex";

            # Left side
            $diff_input1 = &f__regex( $diff_input1, $kregex, $regex_input1, "keep" );

            # Right side
            $diff_input2 = &f__regex( $diff_input2, $kregex, $regex_input2, "keep" );
        } 

        #print "Command is: diff -y -W $diff_width \"$diff_input1\" \"$diff_input2\" | egrep \"[\\\|\|\<\|\>]\" > $session_file\n";
        my $command = "diff -y -W $diff_width \"$diff_input1\" \"$diff_input2\" | egrep \"[\\\|\|\<\|\>]\" > $session_file";
        #print "Command: $command\n";
        system( "$command" );

        my $dev;
        my $ino;
        my $mode;
        my $nlink;
        my $uid;
        my $gid;
        my $rdev;
        my $size;
        my $atime;
        my $mtime;
        my $ctime;
        my $blksize;
        my $blocks;

        if ( -e "$session_file" ) {
            ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ) = stat( $session_file );
        }

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

            print "    Creating diff results: $url/index.html\n";
            print "    \(Actual file: $output_dir/index.html\)\n";

            if (( $size ne "" ) && ( $size > 0 )) {
                # Build $left_session_file
                my $command = "awk -F'\]' '{print \$1}' $session_file";

                open( COMMAND, "$command |" );
                chomp( my @line_numbers = <COMMAND> );
                close( COMMAND );

                open( INPUT, "<", $diff_input1 );
                open( OUTPUT, ">", $left_session_file );
        
                while ( my $line = <INPUT> ) {
                    chomp( $line );

                    foreach my $line_number ( @line_numbers ) {
                        $line_number =~ s/[^0-9]//g;

                        if ( $line =~ /^\[line-$line_number\]\ / ) {
                            print OUTPUT "$line\n";
                        }

                    }

                }

                close( INPUT );
                close( OUTPUT );

                # Build $right_session_file
                my $command = "awk -F'[\\\||<|>]' '{print \$NF}' $session_file | awk -F'\]' '{print \$1}'";

                open( COMMAND, "$command |" );
                chomp( my @line_numbers = <COMMAND> );
                close( COMMAND );

                open( INPUT, "<", $diff_input2 );
                open( OUTPUT, ">", $right_session_file );
        
                while ( my $line = <INPUT> ) {
                    chomp( $line );

                    foreach my $line_number ( @line_numbers ) {
                        $line_number =~ s/[^0-9]//g;

                        if ( $line =~ /^\[line-$line_number\]\ / ) {
                            print OUTPUT "$line\n";
                        }

                    }

                }

                close( INPUT );
                close( OUTPUT );

                my $command = "vimdiff \"$left_session_file\" \"$right_session_file\" -c ':colorscheme $colorscheme' +TOhtml '+w! $output_dir/index.html' '+qall!' > /dev/null 2>\&1";
                system( "$command" );
            } else {
                open( OUTPUT, ">", "$output_dir/index.html" );
                print OUTPUT "<html>\n    <body>\n        No differences found\n    </body>\n</html>\n";
                close( OUTPUT);
            }

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
