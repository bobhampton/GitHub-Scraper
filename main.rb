# main.rb

# Main entry point for running the GitHub scraper pipeline
 
require_relative "./environment"
require_relative "./services/github_repo_importer"
require_relative "./services/github_rate_limiter"
require_relative "./services/graphql_pull_request_importer"

require 'octokit'

access_token = ENV['GITHUB_TOKEN']
unless access_token
  puts "❌ GITHUB_TOKEN environment variable is not set."
  exit 1
end

# Check API rate limit before starting
GitHubRateLimiter.new.log_status

# Import all repositories for the organization
GitHubRepoImporter.new.import

# For each repository, import pull requests and reviews
Repository.all.each do |repo|
  GitHubRateLimiter.new.log_status
  GraphqlPullRequestImporter.new(repo).import
end

puts "✅ Done!"
