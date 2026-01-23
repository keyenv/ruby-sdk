# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'

# Integration tests that run against the live KeyEnv API.
# Requires KEYENV_SERVICE_TOKEN and KEYENV_PROJECT_ID environment variables.
RSpec.describe KeyEnv::Client, :integration do
  let(:token) { ENV['KEYENV_SERVICE_TOKEN'] }
  let(:project_id) { ENV['KEYENV_PROJECT_ID'] }
  let(:environment) { 'development' }
  let(:client) { described_class.new(token: token) }
  let(:test_secret_key) { "TEST_INTEGRATION_#{SecureRandom.hex(4).upcase}" }

  before(:all) do
    skip 'KEYENV_SERVICE_TOKEN and KEYENV_PROJECT_ID must be set' unless ENV['KEYENV_SERVICE_TOKEN'] && ENV['KEYENV_PROJECT_ID']
  end

  after do
    # Clean up test secret if it exists
    client.delete_secret(project_id, environment, test_secret_key) rescue nil
  end

  describe '#list_projects' do
    it 'returns projects' do
      projects = client.list_projects
      expect(projects).to be_an(Array)
      expect(projects).not_to be_empty
    end
  end

  describe '#get_project' do
    it 'returns project details' do
      project = client.get_project(project_id)
      expect(project).to be_a(Hash)
      expect(project['id']).to eq(project_id)
      expect(project['name']).not_to be_nil
    end
  end

  describe '#list_environments' do
    it 'returns environments' do
      environments = client.list_environments(project_id)
      expect(environments).to be_an(Array)
      expect(environments).not_to be_empty
    end
  end

  describe 'secret CRUD operations' do
    it 'creates, reads, updates, and deletes a secret' do
      # Create
      test_value = "test-value-#{Time.now.to_i}"
      secret = client.set_secret(project_id, environment, test_secret_key, test_value)
      expect(secret['key']).to eq(test_secret_key)

      # Read
      retrieved = client.get_secret(project_id, environment, test_secret_key)
      expect(retrieved['key']).to eq(test_secret_key)
      expect(retrieved['value']).to start_with('test-value-')

      # List includes our secret
      secrets = client.get_secrets(project_id, environment)
      expect(secrets.any? { |s| s['key'] == test_secret_key }).to be true

      # Update
      updated_value = "updated-value-#{Time.now.to_i}"
      client.set_secret(project_id, environment, test_secret_key, updated_value)
      client.clear_cache(project_id, environment)
      updated = client.get_secret(project_id, environment, test_secret_key)
      expect(updated['value']).to eq(updated_value)

      # Delete
      client.delete_secret(project_id, environment, test_secret_key)
      client.clear_cache(project_id, environment)
      expect { client.get_secret(project_id, environment, test_secret_key) }.to raise_error(KeyEnv::Error)
    end
  end

  describe '#generate_env_file' do
    before do
      client.set_secret(project_id, environment, test_secret_key, 'test-value')
    end

    it 'generates valid .env content' do
      env_content = client.generate_env_file(project_id, environment)
      expect(env_content).to be_a(String)
      expect(env_content).to include("#{test_secret_key}=")
    end
  end
end
