# db/migrate/001_create_repositories.rb

# Migration for creating the repositories table

require_relative "../../environment"
require "active_record"

class CreateRepositories < ActiveRecord::Migration[7.0]
  def change
    create_table :repositories do |t|
      t.string  :name    # Repository name
      t.string  :url     # Repository URL
      t.boolean :private, :archived # Flags for privacy and archival status
      t.timestamps       # created_at and updated_at
    end
  end
end