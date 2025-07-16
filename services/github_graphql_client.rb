# services/github_graphql_client.rb

require "net/http"
require "json"
require "uri"
require "timeout"

# Custom error class for clean retry flow
class RateLimitError < StandardError; end

# Handles GitHub GraphQL API interactions with retry and rate limit handling.
class GitHubGraphqlClient
  GITHUB_GRAPHQL_ENDPOINT = URI("https://api.github.com/graphql")
  MAX_RETRIES = 3
  TIMEOUT = 10

  # @param token [String] GitHub access token
  # @param verbose [Boolean] Enable verbose logging
  def initialize(token = ENV["GITHUB_TOKEN"], verbose: true)
    @token = token
    @verbose = verbose
  end

  # Executes a GraphQL query with exponential backoff and retry logic
  #
  # @param query_string [String] The GraphQL query string
  # @param variables [Hash] Optional query variables
  # @return [Hash] The parsed response data
  def execute(query_string, variables = {})
    retries = 0

    begin
      response = post(query_string, variables)

      raise "GraphQL 5xx error" if response.code.to_i >= 500

      json = JSON.parse(response.body)

      if json["errors"]
        rate_limited = json["errors"].any? { |e| e["type"] == "RATE_LIMITED" }
        raise RateLimitError, json["errors"].to_s if rate_limited

        raise "GraphQL error(s): #{json["errors"]}"
      end

      json["data"]

    rescue RateLimitError => e
      retries += 1
      if retries <= MAX_RETRIES
        sleep_time = [2**retries, 60].min
        log "⚠️ GraphQL rate limit hit. Retrying in #{sleep_time}s (attempt #{retries})..."
        sleep(sleep_time)
        retry
      else
        log "🧊 Final cooldown after rate limits. Sleeping 60s..."
        sleep(60)
        raise "🔥 Rate limit exceeded after #{MAX_RETRIES} attempts: #{e.message}"
      end

    rescue StandardError => e
      retries += 1
      if retries <= MAX_RETRIES
        sleep_time = [2**retries, 60].min
        log "⚠️ GraphQL error: #{e.message}. Retrying in #{sleep_time}s (attempt #{retries})..."
        sleep(sleep_time)
        retry
      else
        log "🧊 Cooling down for 60s after persistent failure..."
        sleep(60)
        raise "🔥 GraphQL failed after #{MAX_RETRIES} retries: #{e.message}"
      end
    end
  end

  private

  # Sends the HTTP POST request to the GitHub GraphQL API
  #
  # @param query_string [String] The GraphQL query
  # @param variables [Hash] The GraphQL variables
  # @return [Net::HTTPResponse] Raw HTTP response
  def post(query_string, variables)
    req = Net::HTTP::Post.new(GITHUB_GRAPHQL_ENDPOINT)
    req["Authorization"] = "bearer #{@token}"
    req["Content-Type"] = "application/json"
    req.body = { query: query_string, variables: variables }.to_json

    Timeout.timeout(TIMEOUT) do
      Net::HTTP.start(GITHUB_GRAPHQL_ENDPOINT.hostname, GITHUB_GRAPHQL_ENDPOINT.port, use_ssl: true) do |http|
        http.request(req)
      end
    end
  rescue Timeout::Error => e
    raise "⏱️ Request timed out: #{e.message}"
  rescue SocketError, EOFError => e
    raise "🌐 Network error: #{e.message}"
  end

  # Logs a message to STDOUT if verbose is enabled
  #
  # @param message [String] Message to log
  # @return [void]
  def log(message)
    puts message if @verbose
  end
end
