# frozen_string_literal: true

# KeyEnv Ruby SDK - Secure secrets management for development teams.

require_relative "keyenv/version"
require_relative "keyenv/error"
require_relative "keyenv/types"
require_relative "keyenv/client"

module KeyEnv
  class << self
    # Create a new KeyEnv client.
    #
    # @param token [String] Service token for authentication
    # @param timeout [Integer] Request timeout in seconds (default: 30)
    # @param cache_ttl [Integer] Cache TTL in seconds (default: 0 = disabled)
    # @param base_url [String, nil] Custom API base URL (default: https://api.keyenv.dev)
    # @return [Client] KeyEnv client instance
    #
    # @example
    #   client = KeyEnv.new(token: "your-service-token")
    #   secrets = client.export_secrets(project_id: "proj_123", environment: "production")
    #
    def new(token:, timeout: 30, cache_ttl: 0, base_url: nil)
      Client.new(token: token, timeout: timeout, cache_ttl: cache_ttl, base_url: base_url)
    end

    # Create a new KeyEnv client (alternative syntax).
    #
    # @param token [String] Service token for authentication
    # @param timeout [Integer] Request timeout in seconds (default: 30)
    # @param cache_ttl [Integer] Cache TTL in seconds (default: 0 = disabled)
    # @param base_url [String, nil] Custom API base URL (default: https://api.keyenv.dev)
    # @return [Client] KeyEnv client instance
    #
    # @example
    #   client = KeyEnv.create("your-service-token")
    #   secret = client.get_secret(project_id: "proj_123", environment: "production", key: "API_KEY")
    #
    def create(token, timeout: 30, cache_ttl: 0, base_url: nil)
      Client.new(token: token, timeout: timeout, cache_ttl: cache_ttl, base_url: base_url)
    end
  end
end
