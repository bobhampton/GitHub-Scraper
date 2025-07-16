# db/migrate/003_create_pull_requests.rb

# Migration for creating the pull_requests table

require_relative "../../environment"

class CreatePullRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :pull_requests do |t|
      t.references :repository, foreign_key: true         # Associated repository
      t.integer    :pr_number                             # Pull request number
      t.string     :title                                 # PR title
      t.datetime   :updated_at_on_github                  # Last update time on GitHub
      t.datetime   :closed_at                             # When PR was closed
      t.datetime   :merged_at                             # When PR was merged
      t.integer    :additions                             # Lines added
      t.integer    :deletions                             # Lines deleted
      t.integer    :changed_files                         # Number of files changed
      t.integer    :commits                               # Number of commits in PR
      t.references :author, foreign_key: { to_table: :users } # PR author (user)
      t.timestamps
    end
  end
end
