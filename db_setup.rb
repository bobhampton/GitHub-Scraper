# db_setup.rb

# Sets up the ActiveRecord connection to the PostgreSQL database

require "active_record"

ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  database: ENV["PGDATABASE"] || "github_scraper_dev",
  username: ENV["PGUSER"],
  password: ENV["PGPASSWORD"],     # optional if no password locally
  host: "localhost"
)

ActiveRecord::Base.logger = Logger.new(STDOUT)
