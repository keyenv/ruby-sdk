# KeyEnv Ruby SDK

Official Ruby SDK for [KeyEnv](https://keyenv.dev) - Secure secrets management for development teams.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'keyenv'
```

And then execute:

```bash
bundle install
```

Or install it yourself:

```bash
gem install keyenv
```

## Quick Start

```ruby
require 'keyenv'

client = KeyEnv.new(token: ENV['KEYENV_TOKEN'])

# Load secrets into ENV
client.load_env(project_id: 'your-project-id', environment: 'production')
puts ENV['DATABASE_URL']
```

## Usage

### Initialize the Client

```ruby
require 'keyenv'

# Using keyword argument
client = KeyEnv.new(token: 'your-service-token')

# Alternative syntax
client = KeyEnv.create('your-service-token')

# With custom timeout and caching
client = KeyEnv.new(token: 'your-token', timeout: 60, cache_ttl: 300)
```

### Export Secrets

```ruby
# Get all secrets as a list
secrets = client.export_secrets(project_id: 'proj_123', environment: 'production')
secrets.each do |secret|
  puts "#{secret.key}=#{secret.value}"
end

# Get secrets as a hash
env = client.export_secrets_as_hash(project_id: 'proj_123', environment: 'production')
puts env['DATABASE_URL']

# Load directly into ENV
count = client.load_env(project_id: 'proj_123', environment: 'production')
puts "Loaded #{count} secrets"
```

### Manage Secrets

```ruby
# Get a single secret
secret = client.get_secret(project_id: 'proj_123', environment: 'production', key: 'DATABASE_URL')
puts secret.value

# Set a secret (creates or updates)
client.set_secret(
  project_id: 'proj_123',
  environment: 'production',
  key: 'API_KEY',
  value: 'sk_live_...'
)

# Delete a secret
client.delete_secret(project_id: 'proj_123', environment: 'production', key: 'OLD_KEY')
```

### Bulk Import

```ruby
result = client.bulk_import(
  project_id: 'proj_123',
  environment: 'development',
  secrets: [
    KeyEnv::BulkSecretItem.new(key: 'DATABASE_URL', value: 'postgres://localhost/mydb'),
    KeyEnv::BulkSecretItem.new(key: 'REDIS_URL', value: 'redis://localhost:6379'),
    { 'key' => 'API_KEY', 'value' => 'sk_test_...' }  # Also accepts hashes
  ],
  overwrite: true
)
puts "Created: #{result.created}, Updated: #{result.updated}"
```

### Generate .env File

```ruby
env_content = client.generate_env_file(project_id: 'proj_123', environment: 'production')
File.write('.env', env_content)
```

### List Projects and Environments

```ruby
# List all projects
projects = client.list_projects
projects.each do |project|
  puts "#{project.name} (#{project.id})"
end

# Get project with environments
project = client.get_project(project_id: 'proj_123')
project.environments.each do |env|
  puts "  - #{env.name}"
end
```

### Service Token Info

```ruby
# Get current user or service token info
user = client.get_current_user

if user.auth_type == 'service_token'
  # Service tokens can access multiple projects
  puts "Projects: #{user.project_ids}"
  puts "Scopes: #{user.scopes}"
end
```

## Error Handling

```ruby
require 'keyenv'

begin
  secret = client.get_secret(project_id: 'proj_123', environment: 'production', key: 'MISSING_KEY')
rescue KeyEnv::NotFoundError => e
  puts "Secret not found: #{e.message}"
rescue KeyEnv::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue KeyEnv::Error => e
  puts "Error #{e.status}: #{e.message}"
end
```

### Error Types

| Error | Description |
|-------|-------------|
| `KeyEnv::Error` | Base error class |
| `KeyEnv::AuthenticationError` | Authentication failed (401) |
| `KeyEnv::NotFoundError` | Resource not found (404) |
| `KeyEnv::ValidationError` | Invalid request (422) |
| `KeyEnv::RateLimitError` | Rate limit exceeded (429) |
| `KeyEnv::ConnectionError` | Network/connection error |
| `KeyEnv::TimeoutError` | Request timeout |

## Caching

For serverless environments or high-traffic applications, enable caching to reduce API calls:

```ruby
# Cache secrets for 5 minutes
client = KeyEnv.new(token: 'your-token', cache_ttl: 300)

# Or use environment variable
ENV['KEYENV_CACHE_TTL'] = '300'
client = KeyEnv.new(token: 'your-token')

# Manually clear cache
client.clear_cache  # Clear all
client.clear_cache(project_id: 'proj_123')  # Clear project
client.clear_cache(project_id: 'proj_123', environment: 'production')  # Clear specific
```

## API Reference

### `KeyEnv.new(token:, timeout:, cache_ttl:)`

Create a new KeyEnv client.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `token` | `String` | Yes | - | Service token |
| `timeout` | `Integer` | No | `30` | Request timeout (seconds) |
| `cache_ttl` | `Integer` | No | `0` | Cache TTL (seconds, 0 = disabled) |

### Methods

| Method | Description |
|--------|-------------|
| `get_current_user` | Get current user/token info |
| `list_projects` | List all accessible projects |
| `get_project(project_id:)` | Get project with environments |
| `list_environments(project_id:)` | List environments in a project |
| `list_secrets(project_id:, environment:)` | List secret keys (no values) |
| `export_secrets(project_id:, environment:)` | Export secrets with values |
| `export_secrets_as_hash(project_id:, environment:)` | Export as hash |
| `get_secret(project_id:, environment:, key:)` | Get single secret |
| `set_secret(project_id:, environment:, key:, value:)` | Create or update secret |
| `delete_secret(project_id:, environment:, key:)` | Delete secret |
| `bulk_import(project_id:, environment:, secrets:)` | Bulk import secrets |
| `load_env(project_id:, environment:)` | Load secrets into ENV |
| `generate_env_file(project_id:, environment:)` | Generate .env file content |
| `list_permissions(project_id:, environment:)` | List permissions |
| `set_permission(project_id:, environment:, user_id:, role:)` | Set permission |
| `delete_permission(project_id:, environment:, user_id:)` | Delete permission |
| `get_my_permissions(project_id:)` | Get current user's permissions |

## Requirements

- Ruby 3.0+

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Generate documentation
bundle exec rake yard
```

## License

MIT
