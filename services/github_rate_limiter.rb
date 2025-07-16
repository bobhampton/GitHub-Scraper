# services/github_rate_limiter.rb

require "octokit"
require_relative "../environment" unless defined?(ERROR_LOGGER)

# Monitors and enforces GitHub API rate limits using Octokit
class GitHubRateLimiter
  # Initializes the Octokit client with GitHub token
  #
  # @return [void]
  def initialize
    @client = Octokit::Client.new(access_token: ENV["GITHUB_TOKEN"])
  end

  # Logs current rate limit status and sleeps if quota is below buffer
  #
  # @param buffer [Integer] Minimum number of remaining requests required before pausing
  # @return [void]
  def log_status(buffer = 100)
    rate = @client.rate_limit

    puts "🔢 GitHub API Rate: #{rate.remaining}/#{rate.limit} remaining"
    puts "⏳ Resets at: #{rate.resets_at}"

    if rate.remaining < buffer
      wait_time = [(rate.resets_at - Time.now).to_i, 1].max
      puts "⚠️ Low API quota: Sleeping #{wait_time}s until reset at #{rate.resets_at}"
      sleep(wait_time)
    end

  rescue Faraday::SSLError => e
    puts "❌ SSL Error during rate limit check: #{e.message}. Retrying in 5s..."
    ERROR_LOGGER.error("Faraday SSL error in rate limiter: #{e.message}\n#{e.backtrace.join("\n")}")
    sleep 5
    retry

  rescue OpenSSL::SSL::SSLError => e
    puts "❌ OpenSSL error during rate limit check: #{e.message}. Retrying in 5s..."
    ERROR_LOGGER.error("OpenSSL SSL error in rate limiter: #{e.message}\n#{e.backtrace.join("\n")}")
    sleep 5
    retry

  rescue Octokit::Error => e
    puts "⚠️ Failed to fetch rate limit: #{e.message}"
    ERROR_LOGGER.error("Octokit error in rate limiter: #{e.message}\n#{e.backtrace.join("\n")}")
  end
end
