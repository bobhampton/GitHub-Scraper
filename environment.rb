# environment.rb

# Loads environment, database setup, models, and configures logging

require "bundler/setup"
require "dotenv/load" 
require_relative "./db_setup"
require_relative "./models/repository"
require_relative "./models/review"
require_relative "./models/user"
require_relative "./models/pull_request"
require "logger"

LOG_DIR = File.expand_path("../log", __dir__)
Dir.mkdir(LOG_DIR) unless Dir.exist?(LOG_DIR)

ERROR_LOGGER = Logger.new("#{LOG_DIR}/import_errors.log", "daily")
ERROR_LOGGER.level = Logger::ERROR