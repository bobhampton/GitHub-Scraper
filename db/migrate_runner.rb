# db/migrate_runner.rb

# Script to run all database migrations in the migrate directory

require_relative "../environment"
require "active_record"

migrations_path = File.expand_path("migrate", __dir__)

migration_context = ActiveRecord::MigrationContext.new(migrations_path)
migration_context.migrate