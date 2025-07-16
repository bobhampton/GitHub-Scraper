# db/migrate/006_create_reviews.rb

# Migration for creating the reviews table

require_relative "../../environment"

class CreateReviews < ActiveRecord::Migration[7.0]
  def change
    create_table :reviews do |t|
      t.references :pull_request, foreign_key: true                # Associated pull request
      t.references :reviewer, foreign_key: { to_table: :users }    # Reviewer (user)
      t.string     :state                                          # Review state (e.g., approved, changes requested)
      t.datetime   :submitted_at                                   # When the review was submitted
      t.timestamps                                                 # created_at and updated_at
    end
    add_index :reviews, [:pull_request_id, :reviewer_id, :submitted_at], unique: true, name: "index_reviews_on_pr_reviewer_and_time" # Ensure uniqueness per PR, reviewer, and time
  end
end