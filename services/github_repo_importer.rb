# services/github_repo_importer.rb

require "octokit"
require_relative "../models/repository"

# Imports all public/private repositories from a GitHub organization using Octokit.
class GitHubRepoImporter
  # @param org [String] GitHub organization name (e.g., "vercel")
  def initialize(org = ENV["GITHUB_ORG"] || "vercel")
    @org = org
    @client = Octokit::Client.new(access_token: ENV["GITHUB_TOKEN"])
    @client.auto_paginate = false
  end

  # Imports repositories from GitHub and stores them in the database.
  #
  # @return [void]
  def import
    page = 1

    loop do
      repos = @client.org_repos(@org, per_page: 100, page: page)
      break if repos.empty?

      repos.each do |repo|
        Repository.find_or_create_by(
          name: repo.full_name,
          url: repo.html_url,
          private: repo.private,
          archived: repo.archived
        )
      end

      page += 1
    end
  rescue Octokit::Error => e
    puts "GitHub API Error: #{e.message}"
  end
end
