#!/usr/bin/perl

# TODO
#	- allow date format specification in account def
#	- allow alternate config file to be specified on the command line

use strict;
use warnings;

# trims whitespace from all arguments

sub trim {
	for (my $i = 0; $i < scalar @_; $i++) {
		$_[$i] =~ s/^\s+//;
		$_[$i] =~ s/\s+$//;
	}
}

# processes the given config text, and parses it into a config data
# structure
#
# will only apply an account's config if it matches the current
# account, given in the second param.
# 
# params:
# 	$configText 	(string) raw text from config file.
#	$account	(string) label for current account being processed
#
# returns:
#	(hash)		parsed config

sub processConfig {
	my %config = ();
	my @types = qw(accounts rules);
	my $configText = shift;
	my $account = shift;

	foreach (@types) {
		my $type = $_;
		(my $def) = $configText =~ m/\[$type\](.*)\[\/$type\]/s;

		trim $def;

		my @lines = split /\n/, $def;

		while (@lines) {
			my $label = shift @lines;
			my $format = shift @lines;

			my @tags = split /,/, $format;
			trim $label, $format, @tags;

			if ($type eq "accounts" && $account eq $label) {
				my %temp;

				for (my $i = 0; $i < scalar @tags; $i++) {
					$temp{$tags[$i]} = $i;
				}

				$config{account} = {%temp};
			} elsif ($type eq "rules") {
				$config{$type}{$label} = [@tags];
			}
		}
	}

	return %config;
}

# returns the usage text

sub usage {
	return "USAGE: $0 <account label> <input file>\n";
}

# processes the given CSV input against the given config data structure,
# and returns a string representing the transactions in a ledger structure
#
# params:
#	$account_1	(string) the label for the current account
#	$input_ref	(array) CSV input to be processed
#	$config_ref	(hash ref) reference to %config hash
#
# returns:
#	(string)	string representing @input in ledger format

sub processTransactions {
	my $account_1 = shift;
	my $input_ref = shift;
	my @input = @{$input_ref};
	my $config_ref = shift;
	my %config = %{$config_ref};
	my @transactions;

	foreach (@input) {
		my $account_2 = "Unmarked";
		my @bits = split /,/;
		my $transaction = "";

		my $date = $bits[$config{account}{date}];
		my $debit = $bits[$config{account}{debit}];
		my $credit = $bits[$config{account}{credit}];
		my $label = $bits[$config{account}{label}];

		$credit = 0 if ($credit eq "");
		$debit = 0 if ($debit eq "");

		my $total = $debit - $credit;

		while (my ($acct, $keys) = each %{$config{rules}}) {
			my @keys = @{$keys};

			foreach (@keys) {
				if ($label =~ /$_/i) {
					$account_2 = $acct;
					last;
				}
			}
		}

		$transaction .= "$date $label\n";
		$transaction .= "  $account_2  \$$total\n";
		$transaction .= "  $account_1\n";

		push @transactions, $transaction;
	}

	return join "\n", @transactions;
}

# main starts here

my $HOME = $ENV{"HOME"};
my $rc = "$HOME/.csv2ledgerrc";
my $fh;
my $text;

if (scalar @ARGV < 2) {
	die usage;
}

my $account_1 = $ARGV[0];
my $inputFile = $ARGV[1];

if (! -e $rc) {
	die "Error: \"The configuration file '$rc' doesn't exist.\"";
}

if (! -e $inputFile) {
	die "Error: \"The input file '$inputFile' doesn't exist.\"";
}

open $fh, $rc or die $!;

local $/ = undef;
$text = <$fh>;
local $/ = "\n";
close $fh;

my %config = processConfig $text, $account_1;

open $fh, $inputFile or die $!;
my @input = <$fh>;
close $fh;

trim @input;

print processTransactions $account_1, [@input], {%config};
