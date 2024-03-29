#!/usr/bin/perl

# TODO
#   - allow date format specification in account def
#   - allow alternate config file to be specified on the command line
#   - test config format with multiple accounts

use strict;
use warnings;

use Config::Auto;
use Data::Dump;

use feature "switch";

# trims whitespace from all arguments

sub trim {
    for (my $i = 0; $i < scalar @_; $i++) {
        $_[$i] =~ s/^\s+//;
        $_[$i] =~ s/\s+$//;
    }
}

sub formatDate {
    my $date = shift;
    my $format = shift;
    my $month = "";
    my $day = "";
    my $year = "";

    for (my $i = 0; $i < length $date; $i++) {
        my $ch = substr $format, $i, 1;
        my $newch = substr $date, $i, 1;

        if ($ch eq "m") {
            $month .= $newch;
        } elsif ($ch eq "d") {
            $day .= $newch;
        } elsif ($ch eq "y") {
            $year .= $newch;
        }
    }

    return "$year/$month/$day";
}

# returns the usage text

sub usage {
    return "USAGE: $0 <account label> <input file>\n";
}

sub processConfig {
    my $config = shift;
    my $account_name = shift;
    my %account_def;

    my @accounts = @{$config->{accounts}};
    my @global_rules = @{$config->{rules}};

    my (@account_rules, @combined_rules);

    foreach my $account (@accounts) {
        if ($account->{name} eq $account_name) {
            foreach my $key (sort keys %$account) {
                given ($key) {
                    when ("rules") {
                        @account_rules = @{$account->{$key}};
                    } when ("columnOrder") {
                        my @columns = @{$account->{columnOrder}};
                        foreach my $i (0 .. $#columns) {
                            $account_def{columns}{$columns[$i]} = $i;
                        }
                    } default {
                        $account_def{$key} = $account->{$key};
                    }
                }
            }
        }
    }

    @combined_rules = (@global_rules, @account_rules);

    my $result = {
        account => \%account_def,
        rules => \@combined_rules
    };

    return $result;
}

# processes the given CSV input against the given config data structure,
# and returns a string representing the transactions in a ledger structure
#
# params:
#   $account_1  (string) the label for the current account
#   $input_ref  (array) CSV input to be processed
#   $config_ref (hash ref) reference to %config hash
#
# returns:
#   (string)    string representing @input in ledger format

sub processTransactions {
    my $account_1 = shift;
    my $input = shift;
    my $config = shift;
    my @transactions;

    foreach (@$input) {
        my $account_2 = "Unmarked";
        my @bits = split /,/;
        my $transaction = "";

        my $rawDate = $bits[$config->{account}{columns}{date}];
        my $dateFormat = $config->{account}{dateFormat};

        my $date = formatDate $rawDate, $dateFormat;
        my $debit = $bits[$config->{account}{columns}{debit}];
        my $credit = $bits[$config->{account}{columns}{credit}];
        my $label = $bits[$config->{account}{columns}{label}];

        $label =~ s/[\t\ ]+/\ /g;

        $credit = 0 if ($credit eq "");
        $debit = 0 if ($debit eq "");

        my $total = $debit - $credit;

        foreach my $rule (@{$config->{rules}}) {
            foreach (@{$rule->{keyWords}}) {
                if ($label =~ /$_/i) {
                    $account_2 = $rule->{account};
                    last;
                }
            }
        }   

        $transaction .= "$date $label\n";
        $transaction .= "  $account_2  \$$total\n";
        $transaction .= "  $account_1\n";

        push @transactions, $transaction;
    }

    return join "", @transactions;
}

# main starts here

my $fh;
my $text;

if (scalar @ARGV < 2) {
    die usage;
}

my $account_1 = $ARGV[0];
my $inputFile = $ARGV[1];

if (! -e $inputFile) {
    die "Error: \"The input file '$inputFile' doesn't exist.\"";
}

my $config = processConfig Config::Auto::parse(), $account_1;

#dd($config);

open $fh, $inputFile or die $!;
my @input = <$fh>;
close $fh;

trim @input;

print processTransactions $account_1, \@input, $config;
