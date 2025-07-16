# models/pull_request.rb

# Model for pull requests

require "active_record"

class PullRequest < ActiveRecord::Base
  belongs_to :repository  # Each pull request is associated with a repository
end
