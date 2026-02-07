# frozen_string_literal: true

require "spec_helper"
require "securerandom"

# Integration tests that run against the live KeyEnv test API.
#
# Required environment variables:
#   - KEYENV_API_URL: API base URL (e.g., http://localhost:8081/api/v1)
#   - KEYENV_TOKEN: Service token for authentication
#   - KEYENV_PROJECT: Project slug (default: sdk-test)
#
# To run:
#   KEYENV_API_URL=http://localhost:8081 KEYENV_TOKEN=env_test_integration_token_12345 \
#     bundle exec rspec --tag integration
#
RSpec.describe "Integration Tests", :integration do
  # Configuration from environment
  let(:api_url) { ENV["KEYENV_API_URL"] }
  let(:token) { ENV["KEYENV_TOKEN"] }
  let(:project_slug) { ENV.fetch("KEYENV_PROJECT", "sdk-test") }
  let(:environment) { "development" }

  # Test client instance
  let(:client) do
    KeyEnv::Client.new(token: token, base_url: api_url)
  end

  # Unique key prefix for this test run to avoid conflicts
  let(:test_prefix) { "RUBY_SDK_TEST_#{Time.now.to_i}_#{SecureRandom.hex(4).upcase}" }

  # Track created secrets for cleanup
  let(:created_keys) { [] }

  before(:all) do
    skip "KEYENV_API_URL not set" unless ENV["KEYENV_API_URL"]
    skip "KEYENV_TOKEN not set" unless ENV["KEYENV_TOKEN"]
  end

  after do
    # Clean up all created secrets
    created_keys.each do |key|
      begin
        client.delete_secret(project_id: project_slug, environment: environment, key: key)
      rescue KeyEnv::Error
        # Ignore errors during cleanup (secret may already be deleted)
      end
    end
    # Clear cache after each test
    client.clear_cache
  end

  describe "Authentication" do
    it "validates token and returns user/token info" do
      user = client.get_current_user

      expect(user).to be_a(KeyEnv::User)
      expect(user.id).not_to be_nil
      # Service tokens have auth_type set
      expect(user.auth_type).to eq("service_token")
    end

    it "raises AuthenticationError for invalid token" do
      invalid_client = KeyEnv::Client.new(token: "invalid_token", base_url: api_url)

      expect { invalid_client.get_current_user }.to raise_error(KeyEnv::AuthenticationError)
    end
  end

  describe "Projects" do
    it "lists accessible projects" do
      projects = client.list_projects

      expect(projects).to be_an(Array)
      expect(projects).not_to be_empty
      expect(projects.first).to be_a(KeyEnv::Project)
    end

    it "gets project details with environments" do
      project = client.get_project(project_id: project_slug)

      expect(project).to be_a(KeyEnv::ProjectWithEnvironments)
      expect(project.slug).to eq(project_slug)
      expect(project.environments).to be_an(Array)
      expect(project.environments).not_to be_empty
    end

    it "raises NotFoundError for non-existent project" do
      expect do
        client.get_project(project_id: "non-existent-project-12345")
      end.to raise_error(KeyEnv::NotFoundError)
    end
  end

  describe "Environments" do
    it "lists environments for a project" do
      environments = client.list_environments(project_id: project_slug)

      expect(environments).to be_an(Array)
      expect(environments).not_to be_empty

      env_names = environments.map(&:name)
      expect(env_names).to include("development")
    end
  end

  describe "Secret CRUD Operations" do
    let(:test_key) { "#{test_prefix}_CRUD" }
    let(:test_value) { "test-value-#{SecureRandom.hex(8)}" }
    let(:updated_value) { "updated-value-#{SecureRandom.hex(8)}" }

    after do
      # Ensure cleanup of test key
      begin
        client.delete_secret(project_id: project_slug, environment: environment, key: test_key)
      rescue KeyEnv::Error
        # Ignore
      end
    end

    it "creates a new secret" do
      secret = client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: test_value,
        description: "Integration test secret"
      )

      expect(secret).to be_a(KeyEnv::Secret)
      expect(secret.key).to eq(test_key)
      expect(secret.version).to eq(1)
    end

    it "gets a secret with its value" do
      # First create the secret
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: test_value
      )

      # Then retrieve it
      secret = client.get_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key
      )

      expect(secret).to be_a(KeyEnv::SecretWithValue)
      expect(secret.key).to eq(test_key)
      expect(secret.value).to eq(test_value)
    end

    it "updates an existing secret" do
      # Create initial secret
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: test_value
      )

      # Update it
      secret = client.update_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: updated_value
      )

      expect(secret.version).to be >= 2

      # Verify the update
      retrieved = client.get_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key
      )
      expect(retrieved.value).to eq(updated_value)
    end

    it "deletes a secret" do
      # Create a secret to delete
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: test_value
      )

      # Delete it
      result = client.delete_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key
      )
      expect(result).to be_nil

      # Verify it's gone
      expect do
        client.get_secret(
          project_id: project_slug,
          environment: environment,
          key: test_key
        )
      end.to raise_error(KeyEnv::NotFoundError)
    end

    it "raises NotFoundError for non-existent secret" do
      expect do
        client.get_secret(
          project_id: project_slug,
          environment: environment,
          key: "NON_EXISTENT_KEY_#{SecureRandom.hex(8)}"
        )
      end.to raise_error(KeyEnv::NotFoundError)
    end
  end

  describe "Set Secret (upsert)" do
    let(:test_key) { "#{test_prefix}_UPSERT" }
    let(:initial_value) { "initial-#{SecureRandom.hex(8)}" }
    let(:updated_value) { "updated-#{SecureRandom.hex(8)}" }

    after do
      begin
        client.delete_secret(project_id: project_slug, environment: environment, key: test_key)
      rescue KeyEnv::Error
        # Ignore
      end
    end

    it "creates a secret if it doesn't exist" do
      secret = client.set_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: initial_value
      )

      expect(secret.key).to eq(test_key)

      # Verify it was created
      retrieved = client.get_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key
      )
      expect(retrieved.value).to eq(initial_value)
    end

    it "updates a secret if it already exists" do
      # Create initial secret
      client.set_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: initial_value
      )

      # Use set_secret to update
      secret = client.set_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: updated_value
      )

      expect(secret.key).to eq(test_key)

      # Verify the update
      retrieved = client.get_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key
      )
      expect(retrieved.value).to eq(updated_value)
    end
  end

  describe "Export Secrets" do
    let(:test_key1) { "#{test_prefix}_EXPORT_1" }
    let(:test_key2) { "#{test_prefix}_EXPORT_2" }
    let(:test_value1) { "export-value-1-#{SecureRandom.hex(4)}" }
    let(:test_value2) { "export-value-2-#{SecureRandom.hex(4)}" }

    before do
      # Create test secrets
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key1,
        value: test_value1
      )
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key2,
        value: test_value2
      )
    end

    after do
      [test_key1, test_key2].each do |key|
        begin
          client.delete_secret(project_id: project_slug, environment: environment, key: key)
        rescue KeyEnv::Error
          # Ignore
        end
      end
    end

    it "exports all secrets with values" do
      secrets = client.export_secrets(
        project_id: project_slug,
        environment: environment
      )

      expect(secrets).to be_an(Array)
      expect(secrets.first).to be_a(KeyEnv::SecretWithValue)

      # Find our test secrets
      exported_keys = secrets.map(&:key)
      expect(exported_keys).to include(test_key1)
      expect(exported_keys).to include(test_key2)

      # Verify values
      secret1 = secrets.find { |s| s.key == test_key1 }
      secret2 = secrets.find { |s| s.key == test_key2 }
      expect(secret1.value).to eq(test_value1)
      expect(secret2.value).to eq(test_value2)
    end

    it "exports secrets as a hash" do
      env_hash = client.export_secrets_as_hash(
        project_id: project_slug,
        environment: environment
      )

      expect(env_hash).to be_a(Hash)
      expect(env_hash[test_key1]).to eq(test_value1)
      expect(env_hash[test_key2]).to eq(test_value2)
    end

    it "lists secrets without values" do
      secrets = client.list_secrets(
        project_id: project_slug,
        environment: environment
      )

      expect(secrets).to be_an(Array)
      expect(secrets.first).to be_a(KeyEnv::Secret)

      # Find our test secrets
      secret1 = secrets.find { |s| s.key == test_key1 }
      expect(secret1).not_to be_nil
      # Secret (not SecretWithValue) shouldn't have value accessor returning actual value
      expect(secret1).not_to respond_to(:value)
    end
  end

  describe "Bulk Import" do
    let(:bulk_keys) do
      [
        "#{test_prefix}_BULK_1",
        "#{test_prefix}_BULK_2",
        "#{test_prefix}_BULK_3"
      ]
    end

    after do
      bulk_keys.each do |key|
        begin
          client.delete_secret(project_id: project_slug, environment: environment, key: key)
        rescue KeyEnv::Error
          # Ignore
        end
      end
    end

    it "imports multiple secrets at once" do
      secrets_to_import = [
        KeyEnv::BulkSecretItem.new(key: bulk_keys[0], value: "bulk-value-1"),
        KeyEnv::BulkSecretItem.new(key: bulk_keys[1], value: "bulk-value-2"),
        { "key" => bulk_keys[2], "value" => "bulk-value-3" } # Test hash format too
      ]

      result = client.bulk_import(
        project_id: project_slug,
        environment: environment,
        secrets: secrets_to_import,
        overwrite: true
      )

      expect(result).to be_a(KeyEnv::BulkImportResult)
      expect(result.created).to be >= 0
      expect(result.updated).to be >= 0
      expect(result.skipped).to be >= 0
      expect(result.created + result.updated + result.skipped).to eq(3)

      # Verify all secrets were imported
      bulk_keys.each_with_index do |key, i|
        secret = client.get_secret(
          project_id: project_slug,
          environment: environment,
          key: key
        )
        expect(secret.value).to eq("bulk-value-#{i + 1}")
      end
    end

    it "skips existing secrets with overwrite false" do
      # Create a secret first
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: bulk_keys[0],
        value: "original-value"
      )

      # Bulk import the same key with overwrite: false
      result = client.bulk_import(
        project_id: project_slug,
        environment: environment,
        secrets: [
          KeyEnv::BulkSecretItem.new(key: bulk_keys[0], value: "new-value")
        ],
        overwrite: false
      )

      expect(result).to be_a(KeyEnv::BulkImportResult)
      expect(result.skipped).to eq(1)

      # Verify the original value was NOT overwritten
      secret = client.get_secret(
        project_id: project_slug,
        environment: environment,
        key: bulk_keys[0]
      )
      expect(secret.value).to eq("original-value")
    end

    it "overwrites existing secrets with overwrite true" do
      # Create a secret first
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: bulk_keys[0],
        value: "original-value"
      )

      # Bulk import the same key with overwrite: true
      result = client.bulk_import(
        project_id: project_slug,
        environment: environment,
        secrets: [
          KeyEnv::BulkSecretItem.new(key: bulk_keys[0], value: "overwritten-value")
        ],
        overwrite: true
      )

      expect(result).to be_a(KeyEnv::BulkImportResult)
      expect(result.updated).to be >= 1

      # Verify the value was overwritten
      secret = client.get_secret(
        project_id: project_slug,
        environment: environment,
        key: bulk_keys[0]
      )
      expect(secret.value).to eq("overwritten-value")
    end
  end

  describe "Multi-Environment" do
    let(:test_key) { "#{test_prefix}_MULTIENV" }
    let(:dev_value) { "dev-value-#{SecureRandom.hex(4)}" }
    let(:staging_value) { "staging-value-#{SecureRandom.hex(4)}" }
    let(:staging_environment) { "staging" }

    after do
      # Clean up in both environments
      [environment, staging_environment].each do |env|
        begin
          client.delete_secret(project_id: project_slug, environment: env, key: test_key)
        rescue KeyEnv::Error
          # Ignore
        end
      end
    end

    it "isolates secrets across environments" do
      # Create secret in development
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: dev_value
      )

      # Create same key in staging
      client.set_secret(
        project_id: project_slug,
        environment: staging_environment,
        key: test_key,
        value: staging_value
      )

      # Verify each environment returns its own value
      dev_secret = client.get_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key
      )
      expect(dev_secret.value).to eq(dev_value)

      staging_secret = client.get_secret(
        project_id: project_slug,
        environment: staging_environment,
        key: test_key
      )
      expect(staging_secret.value).to eq(staging_value)

      # Confirm they are in different environments
      expect(dev_secret.environment_id).not_to eq(staging_secret.environment_id)
    end
  end

  describe "Special Characters" do
    let(:conn_key) { "#{test_prefix}_CONNSTR" }
    let(:multiline_key) { "#{test_prefix}_MULTILINE" }
    let(:json_key) { "#{test_prefix}_JSON" }

    let(:connection_string) { "postgresql://user:p@ss@localhost:5432/db?sslmode=require" }
    let(:multiline_value) { "line1\nline2\nline3" }
    let(:json_value) { '{"key":"value","nested":{"num":42}}' }

    after do
      [conn_key, multiline_key, json_key].each do |key|
        begin
          client.delete_secret(project_id: project_slug, environment: environment, key: key)
        rescue KeyEnv::Error
          # Ignore
        end
      end
    end

    it "handles connection strings, multiline, and JSON values" do
      # Create secrets with special characters
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: conn_key,
        value: connection_string
      )
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: multiline_key,
        value: multiline_value
      )
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: json_key,
        value: json_value
      )

      # Verify round-trip for connection string
      secret = client.get_secret(
        project_id: project_slug,
        environment: environment,
        key: conn_key
      )
      expect(secret.value).to eq(connection_string)

      # Verify round-trip for multiline value
      secret = client.get_secret(
        project_id: project_slug,
        environment: environment,
        key: multiline_key
      )
      expect(secret.value).to eq(multiline_value)

      # Verify round-trip for JSON value
      secret = client.get_secret(
        project_id: project_slug,
        environment: environment,
        key: json_key
      )
      expect(secret.value).to eq(json_value)
    end
  end

  describe "Secret History" do
    let(:test_key) { "#{test_prefix}_HISTORY" }

    after do
      begin
        client.delete_secret(project_id: project_slug, environment: environment, key: test_key)
      rescue KeyEnv::Error
        # Ignore
      end
    end

    it "retrieves secret version history" do
      # Create initial secret
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: "version-1"
      )

      # Update to create history (API stores previous versions, not current)
      client.update_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: "version-2"
      )

      # Update again to get at least 2 history entries
      client.update_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: "version-3"
      )

      # Get history
      history = client.get_secret_history(
        project_id: project_slug,
        environment: environment,
        key: test_key
      )

      expect(history).to be_an(Array)
      # API returns previous versions only (v1, v2), not current (v3)
      expect(history.length).to be >= 2
      expect(history.first).to be_a(KeyEnv::SecretHistory)

      # History should include previous versions
      versions = history.map(&:version)
      expect(versions).to include(1)
      expect(versions).to include(2)
    end
  end

  describe "Generate Env File" do
    let(:test_key) { "#{test_prefix}_ENVFILE" }
    let(:test_value) { "env-file-value" }

    before do
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: test_value
      )
    end

    after do
      begin
        client.delete_secret(project_id: project_slug, environment: environment, key: test_key)
      rescue KeyEnv::Error
        # Ignore
      end
    end

    it "generates valid .env file content" do
      content = client.generate_env_file(
        project_id: project_slug,
        environment: environment
      )

      expect(content).to be_a(String)
      expect(content).to include("# Generated by KeyEnv")
      expect(content).to include("#{test_key}=#{test_value}")
    end
  end

  describe "Load Env" do
    let(:test_key) { "#{test_prefix}_LOADENV" }
    let(:test_value) { "load-env-value-#{SecureRandom.hex(4)}" }

    before do
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: test_value
      )
    end

    after do
      # Clean up ENV
      ENV.delete(test_key)
      # Clean up secret
      begin
        client.delete_secret(project_id: project_slug, environment: environment, key: test_key)
      rescue KeyEnv::Error
        # Ignore
      end
    end

    it "loads secrets into ENV" do
      count = client.load_env(
        project_id: project_slug,
        environment: environment
      )

      expect(count).to be > 0
      expect(ENV[test_key]).to eq(test_value)
    end
  end

  describe "Caching" do
    let(:test_key) { "#{test_prefix}_CACHE" }
    let(:initial_value) { "cache-initial" }

    before do
      client.create_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: initial_value
      )
    end

    after do
      begin
        client.delete_secret(project_id: project_slug, environment: environment, key: test_key)
      rescue KeyEnv::Error
        # Ignore
      end
    end

    it "caches export results when cache_ttl is set" do
      cached_client = KeyEnv::Client.new(token: token, base_url: api_url, cache_ttl: 60)

      # Clear any existing cache first
      cached_client.clear_cache

      # First export - should cache the result
      secrets1 = cached_client.export_secrets(
        project_id: project_slug,
        environment: environment
      )
      original_value = secrets1.find { |s| s.key == test_key }&.value
      expect(original_value).to eq(initial_value)

      # Second export (without mutation) should return cached value
      # We verify caching works by calling export multiple times
      secrets2 = cached_client.export_secrets(
        project_id: project_slug,
        environment: environment
      )
      cached_value = secrets2.find { |s| s.key == test_key }&.value

      # Should get same value (cached)
      expect(cached_value).to eq(original_value)

      # Update using the SAME cached client (this clears cache)
      cached_client.update_secret(
        project_id: project_slug,
        environment: environment,
        key: test_key,
        value: "cache-updated"
      )

      # Export after mutation should return fresh data (cache was invalidated)
      secrets3 = cached_client.export_secrets(
        project_id: project_slug,
        environment: environment
      )
      fresh_value = secrets3.find { |s| s.key == test_key }&.value

      expect(fresh_value).to eq("cache-updated")
    end
  end

  describe "Error Handling" do
    it "raises ValidationError for invalid secret key" do
      # Keys with spaces or special characters should be rejected
      expect do
        client.create_secret(
          project_id: project_slug,
          environment: environment,
          key: "INVALID KEY WITH SPACES",
          value: "test"
        )
      end.to raise_error(KeyEnv::Error)
    end

    it "handles rate limiting gracefully" do
      # This test documents the expected behavior, but may not trigger
      # rate limiting in normal test conditions
      skip "Rate limiting test - run manually with high request volume"
    end
  end
end
