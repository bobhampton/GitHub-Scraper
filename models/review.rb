# models/review.rb

require "active_record"

class Review < ActiveRecord::Base
  belongs_to :pull_request                 # Each review is linked to a pull request
  belongs_to :reviewer, class_name: "User" # Reviewer is a User
end