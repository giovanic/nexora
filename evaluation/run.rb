# Evaluation of the Food AI pipeline on the licensed dataset. Costs money with real providers: never run by the suite.
#
#   cd apps/api && bin/rails runner ../../evaluation/run.rb PROVIDERS=anthropic:<model>,gemini:<model>,openai:<model> [ROUND=r1]
#   cd apps/api && bin/rails runner ../../evaluation/run.rb CATALOG_ONLY=1      (no provider, no network: the match rate only)
#
# The logic is in cli.rb (so the specs can load it without running it). Exit status: 0 done, 1 refused or failed.
require_relative "cli"

exit(Evaluation::Run.main(ARGV))
