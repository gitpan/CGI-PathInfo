#!/usr/bin/perl -w

use strict;
use lib ('./blib','../blib','../lib','./lib');
use CGI::PathInfo;

# General info for writing test modules: 
#
# When running as 'make test' the default
# working directory is the one _above_ the 
# 't/' directory. 

my @do_tests=(1..2);

my $test_subs = { 
       1 => { -code => \&test1, -desc => ' parameter list                 ' },
       2 => { -code => \&test2, -desc => ' values lists                   ' },
};

print $do_tests[0],'..',$do_tests[$#do_tests],"\n";
print STDERR "\n";
my $n_failures = 0;
foreach my $test (@do_tests) {
	my $sub  = $test_subs->{$test}->{-code};
	my $desc = $test_subs->{$test}->{-desc};
	my $failure = '';
	eval { $failure = &$sub; };
	if ($@) {
		$failure = $@;
	}
	if ($failure ne '') {
		chomp $failure;
		print "not ok $test\n";
		print STDERR "    $desc - $failure\n";
		$n_failures++;
	} else {
		print "ok $test\n";
		print STDERR "    $desc - ok\n";

	}
}
print "END\n";
exit;

########################################
# Number of returned parameters        #
########################################
sub test1 {
    $ENV{'PATH_INFO'} = '/test1a-value1/test1b-value2/fake.html';
    my $path_info     = CGI::PathInfo->new;
    my @parms         = $path_info->param;
    if ($#parms != 1) {
        return 'Incorrect parse of PATH_INFO - wrong number of parameters returned';
    }
    my @expected = ( 'test1a', 'test1b' );
    for (my $count = 0; $count <= $#expected; $count++) {
        if($expected[$count] ne $parms[$count]) {
            return "Unexpected key of '$parms[$count]' was found";    
        }
    }

    return '';
}

########################################
# Number of returned values            #
########################################
sub test2 {
    $ENV{'PATH_INFO'} = '/test2b-value1/test2a-value2/test2a-value3/test2a-value4/fake.html';
    my $path_info     = CGI::PathInfo->new;
    my $expected_results = { 'test2a' => [qw(value1)],
                             'test2a' => [qw(value2 value3 value4)],
                           };
    foreach my $test_key (keys %$expected_results) {
        my (@values) = $path_info->param($test_key);
        if ($#values != $#{$expected_results->{$test_key}}) {
            return "Incorrect parse of PATH_INFO - wrong number of values returned for '$test_key'";
        }
        foreach my $test_value (@{$expected_results->{$test_key}}) {
            if ($#values != $#{$expected_results->{$test_key}}) {
                return "Incorrect parse of PATH_INFO - unexpected values returned for '$test_key'";
            }
        }
    }

    return '';
}
