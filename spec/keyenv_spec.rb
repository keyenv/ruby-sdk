# frozen_string_literal: true

RSpec.describe KeyEnv do
  it "has a version number" do
    expect(KeyEnv::VERSION).not_to be_nil
  end

  describe ".new" do
    it "creates a client with token keyword argument" do
      client = KeyEnv.new(token: "test_token")
      expect(client).to be_a(KeyEnv::Client)
    end

    it "raises error without token" do
      expect { KeyEnv.new(token: "") }.to raise_error(ArgumentError)
      expect { KeyEnv.new(token: nil) }.to raise_error(ArgumentError)
    end
  end

  describe ".create" do
    it "creates a client with positional token argument" do
      client = KeyEnv.create("test_token")
      expect(client).to be_a(KeyEnv::Client)
    end
  end
end

RSpec.describe KeyEnv::Client do
  let(:client) { KeyEnv.new(token: "test_token") }

  describe "#get_current_user" do
    it "returns user info" do
      stub_keyenv_request(:get, "/api/v1/users/me", response_body: {
        "id" => "usr_123",
        "email" => "test@example.com",
        "name" => "Test User"
      })

      user = client.get_current_user
      expect(user).to be_a(KeyEnv::User)
      expect(user.id).to eq("usr_123")
      expect(user.email).to eq("test@example.com")
    end
  end

  describe "#list_projects" do
    it "returns list of projects" do
      stub_keyenv_request(:get, "/api/v1/projects", response_body: {
        "projects" => [
          { "id" => "proj_1", "team_id" => "team_1", "name" => "Project 1", "slug" => "project-1" },
          { "id" => "proj_2", "team_id" => "team_1", "name" => "Project 2", "slug" => "project-2" }
        ]
      })

      projects = client.list_projects
      expect(projects.length).to eq(2)
      expect(projects.first).to be_a(KeyEnv::Project)
      expect(projects.first.name).to eq("Project 1")
    end
  end

  describe "#get_project" do
    it "returns project with environments" do
      stub_keyenv_request(:get, "/api/v1/projects/proj_123", response_body: {
        "id" => "proj_123",
        "team_id" => "team_1",
        "name" => "My Project",
        "slug" => "my-project",
        "environments" => [
          { "id" => "env_1", "project_id" => "proj_123", "name" => "development" },
          { "id" => "env_2", "project_id" => "proj_123", "name" => "production" }
        ]
      })

      project = client.get_project(project_id: "proj_123")
      expect(project).to be_a(KeyEnv::ProjectWithEnvironments)
      expect(project.environments.length).to eq(2)
      expect(project.environments.first.name).to eq("development")
    end
  end

  describe "#export_secrets" do
    it "returns secrets with values" do
      stub_keyenv_request(:get, "/api/v1/projects/proj_123/environments/production/secrets/export", response_body: {
        "secrets" => [
          { "id" => "sec_1", "environment_id" => "env_1", "key" => "DATABASE_URL", "value" => "postgres://localhost/db", "version" => 1 },
          { "id" => "sec_2", "environment_id" => "env_1", "key" => "API_KEY", "value" => "sk_test_123", "version" => 1 }
        ]
      })

      secrets = client.export_secrets(project_id: "proj_123", environment: "production")
      expect(secrets.length).to eq(2)
      expect(secrets.first).to be_a(KeyEnv::SecretWithValue)
      expect(secrets.first.key).to eq("DATABASE_URL")
      expect(secrets.first.value).to eq("postgres://localhost/db")
    end
  end

  describe "#export_secrets_as_hash" do
    it "returns secrets as key-value hash" do
      stub_keyenv_request(:get, "/api/v1/projects/proj_123/environments/production/secrets/export", response_body: {
        "secrets" => [
          { "id" => "sec_1", "environment_id" => "env_1", "key" => "DATABASE_URL", "value" => "postgres://localhost/db", "version" => 1 },
          { "id" => "sec_2", "environment_id" => "env_1", "key" => "API_KEY", "value" => "sk_test_123", "version" => 1 }
        ]
      })

      env = client.export_secrets_as_hash(project_id: "proj_123", environment: "production")
      expect(env).to be_a(Hash)
      expect(env["DATABASE_URL"]).to eq("postgres://localhost/db")
      expect(env["API_KEY"]).to eq("sk_test_123")
    end
  end

  describe "#get_secret" do
    it "returns single secret with value" do
      stub_keyenv_request(:get, "/api/v1/projects/proj_123/environments/production/secrets/API_KEY", response_body: {
        "secret" => {
          "id" => "sec_1",
          "environment_id" => "env_1",
          "key" => "API_KEY",
          "value" => "sk_test_123",
          "version" => 1
        }
      })

      secret = client.get_secret(project_id: "proj_123", environment: "production", key: "API_KEY")
      expect(secret).to be_a(KeyEnv::SecretWithValue)
      expect(secret.key).to eq("API_KEY")
      expect(secret.value).to eq("sk_test_123")
    end

    it "raises NotFoundError for missing secret" do
      stub_keyenv_request(:get, "/api/v1/projects/proj_123/environments/production/secrets/MISSING",
        response_body: { "error" => "Secret not found" },
        status: 404
      )

      expect {
        client.get_secret(project_id: "proj_123", environment: "production", key: "MISSING")
      }.to raise_error(KeyEnv::NotFoundError)
    end
  end

  describe "#create_secret" do
    it "creates a new secret" do
      stub_keyenv_request(:post, "/api/v1/projects/proj_123/environments/development/secrets", response_body: {
        "secret" => {
          "id" => "sec_new",
          "environment_id" => "env_1",
          "key" => "NEW_KEY",
          "version" => 1
        }
      })

      secret = client.create_secret(
        project_id: "proj_123",
        environment: "development",
        key: "NEW_KEY",
        value: "new_value"
      )
      expect(secret).to be_a(KeyEnv::Secret)
      expect(secret.key).to eq("NEW_KEY")
    end
  end

  describe "#set_secret" do
    it "updates existing secret" do
      stub_keyenv_request(:put, "/api/v1/projects/proj_123/environments/production/secrets/API_KEY", response_body: {
        "secret" => {
          "id" => "sec_1",
          "environment_id" => "env_1",
          "key" => "API_KEY",
          "version" => 2
        }
      })

      secret = client.set_secret(
        project_id: "proj_123",
        environment: "production",
        key: "API_KEY",
        value: "new_value"
      )
      expect(secret.version).to eq(2)
    end

    it "creates secret when not found" do
      stub_keyenv_request(:put, "/api/v1/projects/proj_123/environments/production/secrets/NEW_KEY",
        response_body: { "error" => "Secret not found" },
        status: 404
      )
      stub_keyenv_request(:post, "/api/v1/projects/proj_123/environments/production/secrets", response_body: {
        "secret" => {
          "id" => "sec_new",
          "environment_id" => "env_1",
          "key" => "NEW_KEY",
          "version" => 1
        }
      })

      secret = client.set_secret(
        project_id: "proj_123",
        environment: "production",
        key: "NEW_KEY",
        value: "value"
      )
      expect(secret.key).to eq("NEW_KEY")
    end
  end

  describe "#delete_secret" do
    it "deletes a secret" do
      stub_request(:delete, "https://api.keyenv.dev/api/v1/projects/proj_123/environments/production/secrets/OLD_KEY")
        .with(headers: { "Authorization" => /^Bearer .+/ })
        .to_return(status: 204, body: "")

      result = client.delete_secret(project_id: "proj_123", environment: "production", key: "OLD_KEY")
      expect(result).to be_nil
    end
  end

  describe "#load_env" do
    it "loads secrets into ENV" do
      stub_keyenv_request(:get, "/api/v1/projects/proj_123/environments/production/secrets/export", response_body: {
        "secrets" => [
          { "id" => "sec_1", "environment_id" => "env_1", "key" => "TEST_VAR", "value" => "test_value", "version" => 1 }
        ]
      })

      count = client.load_env(project_id: "proj_123", environment: "production")
      expect(count).to eq(1)
      expect(ENV["TEST_VAR"]).to eq("test_value")
    ensure
      ENV.delete("TEST_VAR")
    end
  end

  describe "#bulk_import" do
    it "imports multiple secrets" do
      stub_keyenv_request(:post, "/api/v1/projects/proj_123/environments/development/secrets/bulk", response_body: {
        "created" => 2,
        "updated" => 1,
        "skipped" => 0
      })

      result = client.bulk_import(
        project_id: "proj_123",
        environment: "development",
        secrets: [
          KeyEnv::BulkSecretItem.new(key: "VAR1", value: "val1"),
          { "key" => "VAR2", "value" => "val2" }
        ],
        overwrite: true
      )
      expect(result).to be_a(KeyEnv::BulkImportResult)
      expect(result.created).to eq(2)
      expect(result.updated).to eq(1)
    end
  end

  describe "caching" do
    it "caches secrets when cache_ttl is set" do
      client_with_cache = KeyEnv.new(token: "test_token", cache_ttl: 300)

      stub = stub_keyenv_request(:get, "/api/v1/projects/proj_123/environments/production/secrets/export", response_body: {
        "secrets" => [
          { "id" => "sec_1", "environment_id" => "env_1", "key" => "VAR", "value" => "value", "version" => 1 }
        ]
      })

      # First call should hit API
      client_with_cache.export_secrets(project_id: "proj_123", environment: "production")
      # Second call should use cache
      client_with_cache.export_secrets(project_id: "proj_123", environment: "production")

      expect(stub).to have_been_requested.once
    end

    it "does not cache when cache_ttl is 0" do
      stub = stub_keyenv_request(:get, "/api/v1/projects/proj_123/environments/production/secrets/export", response_body: {
        "secrets" => []
      })

      client.export_secrets(project_id: "proj_123", environment: "production")
      client.export_secrets(project_id: "proj_123", environment: "production")

      expect(stub).to have_been_requested.twice
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_keyenv_request(:get, "/api/v1/users/me",
        response_body: { "error" => "Unauthorized" },
        status: 401
      )

      expect { client.get_current_user }.to raise_error(KeyEnv::AuthenticationError)
    end

    it "raises NotFoundError on 404" do
      stub_keyenv_request(:get, "/api/v1/projects/invalid",
        response_body: { "error" => "Project not found" },
        status: 404
      )

      expect { client.get_project(project_id: "invalid") }.to raise_error(KeyEnv::NotFoundError)
    end

    it "raises ValidationError on 422" do
      stub_keyenv_request(:post, "/api/v1/projects",
        response_body: { "error" => "Invalid project name" },
        status: 422
      )

      expect {
        client.create_project(team_id: "team_1", name: "")
      }.to raise_error(KeyEnv::ValidationError)
    end

    it "raises RateLimitError on 429" do
      stub_keyenv_request(:get, "/api/v1/projects",
        response_body: { "error" => "Rate limit exceeded" },
        status: 429
      )

      expect { client.list_projects }.to raise_error(KeyEnv::RateLimitError)
    end
  end
end

RSpec.describe KeyEnv::Error do
  it "formats error message with status" do
    error = KeyEnv::Error.new("Something went wrong", status: 500)
    expect(error.to_s).to eq("KeyEnvError(500): Something went wrong")
  end

  it "formats error message without status" do
    error = KeyEnv::Error.new("Something went wrong")
    expect(error.to_s).to eq("KeyEnvError: Something went wrong")
  end

  it "stores error details" do
    error = KeyEnv::Error.new("Bad request", status: 400, code: "invalid_input", details: { "field" => "name" })
    expect(error.status).to eq(400)
    expect(error.code).to eq("invalid_input")
    expect(error.details).to eq({ "field" => "name" })
  end
end
