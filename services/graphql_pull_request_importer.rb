# services/graphql_pull_request_importer.rb

require_relative "./github_graphql_client"
require_relative "./github_rate_limiter"
require_relative "./github_user_helper"
require_relative "../models/repository"
require_relative "../models/pull_request"
require_relative "../models/review"
require_relative "../models/user"
require_relative "../environment" unless defined?(ERROR_LOGGER)

require "set"

# Imports pull requests + reviews using GraphQL API
class GraphqlPullRequestImporter
  include GitHubUserHelper

  # @param repo [Repository] The repo to import PRs for
  def initialize(repo)
    @repo = repo
    @owner, @name = repo.name.split("/", 2)
    @client = GitHubGraphqlClient.new
    initialize_user_cache
  end

  # Starts the full PR and review import cycle for the repository
  #
  # @return [void]
  def import
    after_cursor = nil
    all_prs = []
    all_reviews = []

    loop do
      puts "📡 Fetching PRs from #{@repo.name} (cursor: #{after_cursor || 'start'})"

      result = fetch_pull_requests(after_cursor)
      break unless result

      prs = result.dig("repository", "pullRequests", "nodes") || []
      page_info = result.dig("repository", "pullRequests", "pageInfo") || {}
      after_cursor = page_info["endCursor"]

      # Preload authors
      logins = prs.map { |pr| pr.dig("author", "login") }.compact.uniq
      preload_users(logins)

      prs.each do |pr|
        author = find_or_create_user(prepare_user(pr["author"]))
        all_prs << build_pr_data(pr, author)

        # Fetch reviews for this PR (fully paginated)
        reviews = fetch_all_reviews(pr["number"])
        review_logins = reviews.map { |r| r.dig("author", "login") }.compact.uniq
        preload_users(review_logins)

        seen = Set.new
        reviews.each do |review|
          reviewer = find_or_create_user(prepare_user(review["author"]))
          next unless reviewer

          key = [pr["number"], reviewer.id, review["submittedAt"]]
          next if seen.include?(key)

          seen << key
          all_reviews << build_review_data(pr["number"], reviewer.id, review)
        end
      end

      if ENV["TEST_MODE"] == "true"
        puts "🧪 TEST_MODE active: stopping after first page"
        break
      end

      break unless page_info["hasNextPage"]
    end

    persist_data(all_prs, all_reviews)
    @repo.update(last_synced_at: Time.now)
  end

  private

  # Executes GraphQL query to fetch PRs
  #
  # @param after_cursor [String, nil] Pagination cursor
  # @return [Hash, nil] Response from GitHub GraphQL API
  def fetch_pull_requests(after_cursor)
    query = <<~GRAPHQL
      query($owner: String!, $name: String!, $after: String) {
        repository(owner: $owner, name: $name) {
          pullRequests(first: 100, after: $after, orderBy: {field: UPDATED_AT, direction: DESC}) {
            pageInfo {
              endCursor
              hasNextPage
            }
            nodes {
              number
              title
              updatedAt
              closedAt
              mergedAt
              additions
              deletions
              changedFiles
              commits { totalCount }
              author {
                login
                avatarUrl
                url
                __typename
              }
            }
          }
        }
      }
    GRAPHQL

    @client.execute(query, { owner: @owner, name: @name, after: after_cursor })
  rescue => e
    puts "❌ Failed to fetch pull requests for #{@repo.name}: #{e.message}"
    nil
  end

  # Fully paginates and collects all reviews for a PR
  #
  # @param pr_number [Integer] GitHub pull request number
  # @return [Array<Hash>] Review objects returned from GraphQL
  def fetch_all_reviews(pr_number)
    reviews = []
    after = nil

    loop do
      GitHubRateLimiter.new.log_status(100)
      result = @client.execute(REVIEW_QUERY, {
        owner: @owner,
        name: @name,
        pr_number: pr_number,
        after: after
      })

      nodes = result.dig("repository", "pullRequest", "reviews", "nodes") || []
      reviews.concat(nodes)

      page_info = result.dig("repository", "pullRequest", "reviews", "pageInfo")
      break unless page_info && page_info["hasNextPage"]

      after = page_info["endCursor"]
    end

    reviews
  rescue => e
    puts "❌ Failed to fetch reviews for PR ##{pr_number}: #{e.message}"
    []
  end

  REVIEW_QUERY = <<~GRAPHQL
    query($owner: String!, $name: String!, $pr_number: Int!, $after: String) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $pr_number) {
          reviews(first: 100, after: $after) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              state
              submittedAt
              author {
                login
                avatarUrl
                url
                __typename
              }
            }
          }
        }
      }
    }
  GRAPHQL

  # Parses author structure into usable hash
  #
  # @param data [Hash, nil] Author data
  # @return [Hash] Cleaned user fields for lookup/insertion
  def prepare_user(data)
    return {} unless data
    {
      login: data["login"],
      type: data["__typename"],
      site_admin: false
    }
  end

  # Builds the hash for a new PullRequest DB entry
  #
  # @param pr [Hash] Raw GraphQL node for PR
  # @param author [User, nil] Optional associated author
  # @return [Hash] Pull request attributes
  def build_pr_data(pr, author)
    {
      repository_id:         @repo.id,
      pr_number:             pr["number"],
      title:                 pr["title"],
      updated_at_on_github:  pr["updatedAt"],
      closed_at:             pr["closedAt"],
      merged_at:             pr["mergedAt"],
      additions:             pr["additions"],
      deletions:             pr["deletions"],
      changed_files:         pr["changedFiles"],
      commits:               pr.dig("commits", "totalCount"),
      author_id:             author&.id,
      created_at:            Time.now,
      updated_at:            Time.now
    }
  end

  # Builds the hash for a new Review DB entry
  #
  # @param pr_number [Integer] PR number
  # @param reviewer_id [Integer] Reviewer user ID
  # @param review [Hash] Raw review data from GraphQL
  # @return [Hash] Review attributes for DB
  def build_review_data(pr_number, reviewer_id, review)
    {
      pull_request_id: nil,
      pr_number: pr_number,
      reviewer_id: reviewer_id,
      state: review["state"],
      submitted_at: review["submittedAt"],
      created_at: Time.now,
      updated_at: Time.now
    }
  end

  # Inserts pull requests and reviews into the database
  #
  # @param prs [Array<Hash>] Pull requests to persist
  # @param reviews [Array<Hash>] Reviews to persist
  # @return [void]
  def persist_data(prs, reviews)
    return if prs.empty?

    PullRequest.upsert_all(prs, unique_by: %i[repository_id pr_number])
    pr_map = PullRequest
               .where(repository_id: @repo.id, pr_number: prs.map { |p| p[:pr_number] })
               .pluck(:pr_number, :id).to_h

    reviews.each do |review|
      review[:pull_request_id] = pr_map[review.delete(:pr_number)]
    end

    reviews.uniq! { |r| [r[:pull_request_id], r[:reviewer_id], r[:submitted_at]] }
    if reviews.any?
      begin
        result = Review.insert_all(reviews, unique_by: %i[pull_request_id reviewer_id submitted_at])
        inserted = result.try(:rows)&.size || 0
        skipped = reviews.size - inserted
        puts "📝 Reviews inserted: #{inserted}, Skipped (conflicts): #{skipped}"
      rescue => e
        ERROR_LOGGER.error("Review insert failed: #{e.message}\n#{e.backtrace.join("\n")}")
      end
    end
  end
end
