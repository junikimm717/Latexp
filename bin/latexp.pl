#!/usr/bin/env perl -w

use strict;
use warnings;
use diagnostics;
use File::Spec;
use File::Basename;

my @files = ();
my $od = "";
my $sd = "";
my $ext = "";

sub error {
    my $msg = shift or die "error call has no message.";
    print STDERR "\e[1;31merror:\e[0m $msg\n";
    exit 1;
}

sub wn {
    my $msg = shift or die "wn call has no message.";
    print STDERR "\e[1;35mwarning:\e[0m $msg\n";
}

sub help {
    my @l = grep /^-h$/ , @ARGV;
    if (@l) {
        my $dirname = File::Spec->rel2abs(dirname(__FILE__));
        open(FH, "<", "$dirname/help.txt");
        my $c = "";
        while (<FH>) {$c = $c . $_;}
        print STDERR $c;
        exit 0;
    }
}

help;

# parse arguments (and perform checks)
while (@ARGV) {
    $a = shift;
    if ($a eq "--output" or $a eq "-o") {
        $od = shift || error "no output directory specified to $a flag.";
    } elsif ($a eq "--extension" or $a eq "-e") {
        $ext = "." . shift || error "no extension supplied to $a flag.";
    } elsif ($a eq "--scripts" or $a eq "-s") {
        $sd = shift || error "no script directory supplied to $a flag.";
    } elsif ($a =~ /^-.*$/) {
        error "unusable flag $a found.";
    } else {
        if (! -f $a) {
            error "File $a does not exist.";
        }
        push (@files, $a);
    }
}

if (! @files) {error "no input files given.";}
if (! $sd or ! -d $sd) {error "source directory '$sd' does not exist or was not supplied.";}
if (! $od) {error "output directory was not supplied.";}

my @scripts = ();
foreach my $s (glob("$sd/*")) {
    if (-x $s and ! -d $s) {
        $s =~ s/^.*\///g;
        push (@scripts, $s);
    }
}

mkdir $od if (! -d $od);

# execute all of the scripts and save their outputs.
my %sout = ();
foreach my $script (@scripts) {
    $sout{$script} = `$sd/$script`;
    print STDERR "\e[1;33mrunning \e[0mscript $sd/$script\n";
    error "nonzero exit code $? in script $sd/$script. Fix your bugs." if ($? != 0);
    print STDERR "\e[1;32msaved \e[0mscript $sd/$script\n\n";
}

# protection from overwriting.
sub owp {
    my $ofile = shift or die "owp call has no file supplied.";
    my $path = File::Spec->rel2abs($ofile);
    foreach my $file (@files) {
        if (File::Spec->rel2abs($file) eq $path) {
            error "input file $file is the same as output file $ofile.";
        }
    }
}

# preprocess files
# takes in regexes of the form %%script%%

sub prfile {
    my $file = shift || die "prfile call has no file supplied.";
    if (! -f $file) {die "Perhaps an error. $file does not exist in prfile call";}

    # read in file
    my $c = "";
    open (my $fh, "<", "$file"); 
    while (<$fh>) {$c = $c . $_;} close($fh);

    my $f = $file;
    $f =~ s/^.*\///g;
    my $ofile = "$od/$f$ext";

    print STDERR "\e[1;33mpreprocessing\e[0m to $ofile from $file\n";

    # apply regular expressions
    foreach my $script (keys %sout) {
        $c =~ s/%%\h*$script\h*%%/$sout{$script}/g;
    }

    # check for scripts that have not been run yet.
    if ($c =~ /%%.*%%/) {
        wn "non-executed scripts still exist. Check if they are named correctly or are executable.\n";
    }
    open ($fh, ">", $ofile);
    print $fh "$c";
    print STDERR "\e[1;32mgenerated\e[0m file $ofile\n";
}

foreach my $file (@files) {
    my $f = $file;
    $f =~ s/^.*\///g;
    owp "$od/$f$ext";
}

foreach my $file (@files) {
    prfile $file;
}

exit 0;
1;
