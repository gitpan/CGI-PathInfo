use ExtUtils::MakeMaker;
WriteMakefile(
   NAME => 'CGI::PathInfo',
   VERSION_FROM => 'lib/CGI/PathInfo.pm',
   PREREQ_PM => {
      Cwd => 0,
      'Cwd::Ext' => '1.03',
      'LEOCHARRE::DEBUG' => '1.02',
      Carp => 0,
   },
);
