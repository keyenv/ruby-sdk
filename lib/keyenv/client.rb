# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "time"

module KeyEnv
  # KeyEnv API client for managing secrets.
  #
  # @example Basic usage
  #   client = KeyEnv::Client.new(token: "your-service-token")
  #   secrets = client.export_secrets(project_id: "proj_123", environment: "production")
  #
  # @example With caching for serverless environments
  #   client = KeyEnv::Client.new(token: "your-token", cache_ttl: 300)  # 5 minutes
  #
  class Client
    BASE_URL = "https://api.keyenv.dev"
    DEFAULT_TIMEOUT = 30

    # @param token [String] Service token for authentication
    # @param timeout [Integer] Request timeout in seconds (default: 30)
    # @param cache_ttl [Integer] Cache TTL in seconds (default: 0 = disabled)
    # @param base_url [String, nil] Custom API base URL (default: https://api.keyenv.dev)
    def initialize(token:, timeout: DEFAULT_TIMEOUT, cache_ttl: 0, base_url: nil)
      raise ArgumentError, "KeyEnv token is required" if token.nil? || token.empty?

      @token = token
      @timeout = timeout
      @cache_ttl = cache_ttl.positive? ? cache_ttl : ENV.fetch("KEYENV_CACHE_TTL", "0").to_i
      @base_url = base_url || ENV.fetch("KEYENV_API_URL", BASE_URL)
      @base_uri = URI.parse(@base_url)
      @secrets_cache = {}
    end

    # =========================================================================
    # Authentication
    # =========================================================================

    # Get the current user or service token info.
    #
    # @return [User] Current user/token info
    def get_current_user
      data = request(:get, "/api/v1/users/me")
      User.new(data["data"] || data)
    end

    # Validate the token and return user info.
    #
    # @return [User] Current user/token info
    def validate_token
      get_current_user
    end

    # =========================================================================
    # Projects
    # =========================================================================

    # List all accessible projects.
    #
    # @return [Array<Project>] List of projects
    def list_projects
      data = request(:get, "/api/v1/projects")
      (data["data"] || []).map { |p| Project.new(p) }
    end

    # Get a project by ID.
    #
    # @param project_id [String] Project ID
    # @return [ProjectWithEnvironments] Project with environments
    def get_project(project_id:)
      data = request(:get, "/api/v1/projects/#{project_id}")
      ProjectWithEnvironments.new(data["data"] || data)
    end

    # Create a new project.
    #
    # @param team_id [String] Team ID
    # @param name [String] Project name
    # @return [Project] Created project
    def create_project(team_id:, name:)
      data = request(:post, "/api/v1/projects", { team_id: team_id, name: name })
      Project.new(data["data"] || data)
    end

    # Delete a project.
    #
    # @param project_id [String] Project ID
    def delete_project(project_id:)
      request(:delete, "/api/v1/projects/#{project_id}")
      nil
    end

    # =========================================================================
    # Environments
    # =========================================================================

    # List environments in a project.
    #
    # @param project_id [String] Project ID
    # @return [Array<Environment>] List of environments
    def list_environments(project_id:)
      data = request(:get, "/api/v1/projects/#{project_id}/environments")
      (data["data"] || []).map { |e| Environment.new(e) }
    end

    # Create a new environment.
    #
    # @param project_id [String] Project ID
    # @param name [String] Environment name
    # @param inherits_from [String, nil] Parent environment to inherit from
    # @return [Environment] Created environment
    def create_environment(project_id:, name:, inherits_from: nil)
      payload = { name: name }
      payload[:inherits_from] = inherits_from if inherits_from
      data = request(:post, "/api/v1/projects/#{project_id}/environments", payload)
      Environment.new(data["data"] || data)
    end

    # Delete an environment.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    def delete_environment(project_id:, environment:)
      request(:delete, "/api/v1/projects/#{project_id}/environments/#{environment}")
      nil
    end

    # =========================================================================
    # Secrets
    # =========================================================================

    # List secrets in an environment (keys and metadata only).
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @return [Array<Secret>] List of secrets
    def list_secrets(project_id:, environment:)
      data = request(:get, "/api/v1/projects/#{project_id}/environments/#{environment}/secrets")
      (data["data"] || []).map { |s| Secret.new(s) }
    end

    # Export all secrets with their decrypted values.
    # Results are cached when cache_ttl > 0.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @return [Array<SecretWithValue>] List of secrets with values
    def export_secrets(project_id:, environment:)
      cache_key = "#{project_id}:#{environment}"

      # Check cache if TTL > 0
      if @cache_ttl.positive?
        cached = @secrets_cache[cache_key]
        if cached
          secrets, expires_at = cached
          return secrets if Time.now.to_f < expires_at
        end
      end

      data = request(:get, "/api/v1/projects/#{project_id}/environments/#{environment}/secrets/export")
      secrets = (data["data"] || []).map { |s| SecretWithValue.new(s) }

      # Store in cache if TTL > 0
      if @cache_ttl.positive?
        @secrets_cache[cache_key] = [secrets, Time.now.to_f + @cache_ttl]
      end

      secrets
    end

    # Export secrets as a key-value hash.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @return [Hash<String, String>] Secrets as key-value pairs
    def export_secrets_as_hash(project_id:, environment:)
      secrets = export_secrets(project_id: project_id, environment: environment)
      secrets.each_with_object({}) { |s, h| h[s.key] = s.value }
    end

    # Get a single secret with its value.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @param key [String] Secret key
    # @return [SecretWithValue] Secret with value
    def get_secret(project_id:, environment:, key:)
      data = request(:get, "/api/v1/projects/#{project_id}/environments/#{environment}/secrets/#{key}")
      SecretWithValue.new(data["data"] || data)
    end

    # Create a new secret.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @param key [String] Secret key
    # @param value [String] Secret value
    # @param description [String, nil] Optional description
    # @return [Secret] Created secret
    def create_secret(project_id:, environment:, key:, value:, description: nil)
      payload = { key: key, value: value }
      payload[:description] = description if description
      data = request(:post, "/api/v1/projects/#{project_id}/environments/#{environment}/secrets", payload)
      clear_cache(project_id: project_id, environment: environment)
      Secret.new(data["data"] || data)
    end

    # Update a secret's value.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @param key [String] Secret key
    # @param value [String] New secret value
    # @param description [String, nil] Optional new description
    # @return [Secret] Updated secret
    def update_secret(project_id:, environment:, key:, value:, description: nil)
      payload = { value: value }
      payload[:description] = description unless description.nil?
      data = request(:put, "/api/v1/projects/#{project_id}/environments/#{environment}/secrets/#{key}", payload)
      clear_cache(project_id: project_id, environment: environment)
      Secret.new(data["data"] || data)
    end

    # Set a secret (create or update).
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @param key [String] Secret key
    # @param value [String] Secret value
    # @param description [String, nil] Optional description
    # @return [Secret] Created or updated secret
    def set_secret(project_id:, environment:, key:, value:, description: nil)
      update_secret(project_id: project_id, environment: environment, key: key, value: value, description: description)
    rescue NotFoundError
      create_secret(project_id: project_id, environment: environment, key: key, value: value, description: description)
    end

    # Delete a secret.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @param key [String] Secret key
    def delete_secret(project_id:, environment:, key:)
      request(:delete, "/api/v1/projects/#{project_id}/environments/#{environment}/secrets/#{key}")
      clear_cache(project_id: project_id, environment: environment)
      nil
    end

    # Get secret version history.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @param key [String] Secret key
    # @return [Array<SecretHistory>] Secret version history
    def get_secret_history(project_id:, environment:, key:)
      data = request(:get, "/api/v1/projects/#{project_id}/environments/#{environment}/secrets/#{key}/history")
      (data["data"] || []).map { |h| SecretHistory.new(h) }
    end

    # Bulk import secrets.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @param secrets [Array<BulkSecretItem, Hash>] List of secrets to import
    # @param overwrite [Boolean] Whether to overwrite existing secrets
    # @return [BulkImportResult] Import result
    def bulk_import(project_id:, environment:, secrets:, overwrite: false)
      secret_list = secrets.map { |s| s.is_a?(BulkSecretItem) ? s.to_h : s }
      data = request(
        :post,
        "/api/v1/projects/#{project_id}/environments/#{environment}/secrets/bulk",
        { secrets: secret_list, overwrite: overwrite }
      )
      clear_cache(project_id: project_id, environment: environment)
      BulkImportResult.new(data["data"] || data)
    end

    # =========================================================================
    # Utilities
    # =========================================================================

    # Load secrets into ENV.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @return [Integer] Number of secrets loaded
    def load_env(project_id:, environment:)
      secrets = export_secrets(project_id: project_id, environment: environment)
      secrets.each { |s| ENV[s.key] = s.value }
      secrets.size
    end

    # Generate .env file content from secrets.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @return [String] .env file content
    def generate_env_file(project_id:, environment:)
      secrets = export_secrets(project_id: project_id, environment: environment)
      lines = [
        "# Generated by KeyEnv",
        "# Environment: #{environment}",
        "# Generated at: #{Time.now.utc.iso8601}",
        ""
      ]

      secrets.each do |secret|
        value = secret.value
        if value.include?("\n") || value.include?('"') || value.include?("'") || value.include?(" ") || value.include?("$")
          escaped = value.gsub("\\", "\\\\").gsub('"', '\\"').gsub("\n", "\\n").gsub("$", "\\$")
          lines << %(#{secret.key}="#{escaped}")
        else
          lines << "#{secret.key}=#{value}"
        end
      end

      lines.join("\n") + "\n"
    end

    # Clear the secrets cache.
    #
    # @param project_id [String, nil] Clear cache for specific project (optional)
    # @param environment [String, nil] Clear cache for specific environment (requires project_id)
    def clear_cache(project_id: nil, environment: nil)
      if project_id && environment
        cache_key = "#{project_id}:#{environment}"
        @secrets_cache.delete(cache_key)
      elsif project_id
        @secrets_cache.delete_if { |k, _| k.start_with?("#{project_id}:") }
      else
        @secrets_cache.clear
      end
    end

    # =========================================================================
    # Environment Permissions
    # =========================================================================

    # List permissions for an environment.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @return [Array<EnvironmentPermission>] List of permissions
    def list_permissions(project_id:, environment:)
      data = request(:get, "/api/v1/projects/#{project_id}/environments/#{environment}/permissions")
      (data["data"] || []).map { |p| EnvironmentPermission.new(p) }
    end

    # Set a user's permission for an environment.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @param user_id [String] User ID
    # @param role [String] Role ("none", "read", "write", or "admin")
    # @return [EnvironmentPermission] Created or updated permission
    def set_permission(project_id:, environment:, user_id:, role:)
      data = request(
        :put,
        "/api/v1/projects/#{project_id}/environments/#{environment}/permissions/#{user_id}",
        { role: role }
      )
      EnvironmentPermission.new(data)
    end

    # Delete a user's permission for an environment.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @param user_id [String] User ID
    def delete_permission(project_id:, environment:, user_id:)
      request(:delete, "/api/v1/projects/#{project_id}/environments/#{environment}/permissions/#{user_id}")
      nil
    end

    # Bulk set permissions for an environment.
    #
    # @param project_id [String] Project ID
    # @param environment [String] Environment name
    # @param permissions [Array<Hash>] List of permission hashes with "user_id" and "role" keys
    # @return [Array<EnvironmentPermission>] Created or updated permissions
    def bulk_set_permissions(project_id:, environment:, permissions:)
      data = request(
        :put,
        "/api/v1/projects/#{project_id}/environments/#{environment}/permissions",
        { permissions: permissions }
      )
      (data["data"] || []).map { |p| EnvironmentPermission.new(p) }
    end

    # Get current user's permissions for all environments in a project.
    #
    # @param project_id [String] Project ID
    # @return [Array<(Array<MyPermission>, Boolean)>] Tuple of (permissions, is_team_admin)
    def get_my_permissions(project_id:)
      data = request(:get, "/api/v1/projects/#{project_id}/my-permissions")
      permissions = (data["permissions"] || []).map { |p| MyPermission.new(p) }
      is_team_admin = data["is_team_admin"] || false
      [permissions, is_team_admin]
    end

    # Get default permissions for a project.
    #
    # @param project_id [String] Project ID
    # @return [Array<ProjectDefault>] List of project defaults
    def get_project_defaults(project_id:)
      data = request(:get, "/api/v1/projects/#{project_id}/permissions/defaults")
      (data["data"] || []).map { |d| ProjectDefault.new(d) }
    end

    # Set default permissions for a project.
    #
    # @param project_id [String] Project ID
    # @param defaults [Array<Hash>] List of default hashes with "environment_name" and "default_role" keys
    # @return [Array<ProjectDefault>] Updated project defaults
    def set_project_defaults(project_id:, defaults:)
      data = request(
        :put,
        "/api/v1/projects/#{project_id}/permissions/defaults",
        { defaults: defaults }
      )
      (data["data"] || []).map { |d| ProjectDefault.new(d) }
    end

    private

    def request(method, path, body = nil)
      uri = URI.join(@base_url, path)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      request = build_request(method, uri, body)
      response = http.request(request)

      handle_response(response)
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise TimeoutError.new("Request timeout", status: 408)
    rescue SocketError, Errno::ECONNREFUSED => e
      raise ConnectionError.new(e.message, status: 0)
    end

    def build_request(method, uri, body)
      request_class = case method
                      when :get then Net::HTTP::Get
                      when :post then Net::HTTP::Post
                      when :put then Net::HTTP::Put
                      when :delete then Net::HTTP::Delete
                      else raise ArgumentError, "Unknown HTTP method: #{method}"
                      end

      request = request_class.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Content-Type"] = "application/json"
      request["User-Agent"] = "keyenv-ruby/#{VERSION}"
      request.body = JSON.generate(body) if body

      request
    end

    def handle_response(response)
      return nil if response.code == "204"

      body = response.body
      data = body && !body.empty? ? JSON.parse(body) : {}

      unless response.is_a?(Net::HTTPSuccess)
        status = response.code.to_i
        message = data["error"] || "Unknown error"
        code = data["code"]
        details = data["details"]

        error_class = case status
                      when 401 then AuthenticationError
                      when 404 then NotFoundError
                      when 422 then ValidationError
                      when 429 then RateLimitError
                      else Error
                      end

        raise error_class.new(message, status: status, code: code, details: details)
      end

      data
    rescue JSON::ParserError
      raise Error.new(response.body || "Unknown error", status: response.code.to_i)
    end
  end
end
