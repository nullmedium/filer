use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'		=> 'File::DirWalk',
	'VERSION_FROM'	=> 'DirWalk.pm',
	'PREREQ_PM'	=> {
		'File::Basename' => 0,
		'File::Spec' => 0,
	}, 
	($] >= 5.005
		? (AUTHOR     => 'Jens Luedicke <jensl@cpan.org>') 
		: ()
	),
);
