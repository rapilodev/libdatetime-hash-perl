use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Datetime::Hash',
    VERSION_FROM      => 'lib/Datetime/Hash.pm',
    PREREQ_PM         => {}, 
    LIBS              => ['-licui18n -licuuc'], 
    DEFINE            => '', 
    INC               => '-I.', 
);
