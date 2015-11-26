[ '../lib', 'lib' ].each { |d| $:.unshift(d) if File::directory?(d) }
require 'BOAST'
include BOAST

opt_space = OptimizationSpace::new( YAML::load( File::read(ARGV[0]) ) )
oracle = YAML::load( File::read(ARGV[1]) )

optimizer = BruteForceOptimizer::new( opt_space )
puts optimizer.optimize { |opts|
  oracle[opts]
}
puts optimizer.experiments

optimizer = GeneticOptimizer::new( opt_space )
puts optimizer.optimize { |opts|
  oracle[opts]
} 
puts optimizer.experiments