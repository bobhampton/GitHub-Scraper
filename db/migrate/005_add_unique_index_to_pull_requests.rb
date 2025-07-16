# db/migrate/005_add_unique_index_to_pull_requests.rb

# Migration for adding a unique index to pull_requests on [repository_id, pr_number]

require_relative "../../environment"

class AddUniqueIndexToPullRequests < ActiveRecord::Migration[7.0]
  def change
    add_index :pull_requests, [:repository_id, :pr_number], unique: true # Ensure PR numbers are unique per repository
  end
end