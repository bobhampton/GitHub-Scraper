# services/github_user_helper.rb

require "thread"

# Helper module for efficient GitHub user lookup, caching, and database insertion
module GitHubUserHelper
  # Initializes a thread-safe cache for GitHub users
  #
  # @return [void]
  def initialize_user_cache
    @user_cache = {}
    @user_cache_mutex = Mutex.new
  end

  # Preloads users from the DB or inserts them in batch if they don't exist
  #
  # @param logins [Array<String>] Array of GitHub login names to preload
  # @return [void]
  def preload_users(logins)
    return if logins.empty?

    logins = logins.compact.uniq
    known_users = User.where(login: logins).to_a
    known_logins = known_users.map(&:login)

    new_users_data = (logins - known_logins).map do |login|
      {
        login: login,
        user_type: "User",
        site_admin: false,
        created_at: Time.now,
        updated_at: Time.now
      }
    end

    if new_users_data.any?
      begin
        result = User.upsert_all(new_users_data, unique_by: :login)
        inserted = result.try(:rows)&.size || 0
        skipped = new_users_data.size - inserted
        puts "👥 User insertions: #{inserted}, Skipped: #{skipped}"
      rescue => e
        ERROR_LOGGER.error("User upsert failed: #{e.message}\n#{e.backtrace.join("\n")}")
      end
    end

    all_users = User.where(login: logins).to_a
    @user_cache_mutex.synchronize do
      all_users.each { |u| @user_cache[u.login] = u }
    end
  end

  # Looks up a user in cache or creates it on demand
  #
  # @param user_data [Hash] A hash with user fields like :login, :type, :site_admin
  # @option user_data [String] :login GitHub login
  # @option user_data [String] :type GitHub user type (e.g., "User")
  # @option user_data [Boolean] :site_admin Whether the user is an admin
  # @return [User, nil] The found or created User object, or nil if input invalid
  def find_or_create_user(user_data)
    return nil unless user_data.is_a?(Hash) && user_data[:login].present?
    login = user_data[:login]

    @user_cache_mutex.synchronize do
      return @user_cache[login] if @user_cache.key?(login)

      user = User.find_or_create_by(login: login) do |u|
        u.user_type  = user_data[:type]
        u.site_admin = user_data[:site_admin]
      end

      @user_cache[login] = user
    end
  end
end
