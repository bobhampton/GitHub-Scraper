# db/migrate/002_create_users.rb

# Migration for creating the users table

require_relative "../../environment"

class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string  :login, null: false     # GitHub username, must be present
      t.string  :user_type              # User type (avoids STI issues with 'type')
      t.boolean :site_admin             # Admin flag
      t.timestamps
    end

    add_index :users, :login, unique: true # Ensure login is unique
  end
end