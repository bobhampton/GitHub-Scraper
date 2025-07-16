# db/migrate/004_add_last_synced_at_to_repositories.rb

# Migration for adding last_synced_at column to repositories table

require_relative "../../environment"

class AddLastSyncedAtToRepositories < ActiveRecord::Migration[7.0]
  def change
    add_column :repositories, :last_synced_at, :datetime # Tracks last sync time with GitHub
  end
end