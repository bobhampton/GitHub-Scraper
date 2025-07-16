# models/user.rb

require "active_record"

class User < ActiveRecord::Base
  # Disable STI (Single Table Inheritance) to avoid issues with user_type column
  self.inheritance_column = :_type_disabled
  has_many :pull_requests, foreign_key: "author_id" # User's authored pull requests
  has_many :reviews, foreign_key: "reviewer_id"     # User's reviews
end