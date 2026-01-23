# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-23

### Added

- Initial release
- `KeyEnv.new(token:)` and `KeyEnv.create(token)` client creation
- Authentication: `get_current_user`, `validate_token`
- Projects: `list_projects`, `get_project`, `create_project`, `delete_project`
- Environments: `list_environments`, `create_environment`, `delete_environment`
- Secrets: `list_secrets`, `export_secrets`, `export_secrets_as_hash`, `get_secret`
- Secret management: `create_secret`, `update_secret`, `set_secret`, `delete_secret`
- Bulk operations: `bulk_import`, `get_secret_history`
- Utilities: `load_env`, `generate_env_file`, `clear_cache`
- Permissions: `list_permissions`, `set_permission`, `delete_permission`, `bulk_set_permissions`
- Permission queries: `get_my_permissions`, `get_project_defaults`, `set_project_defaults`
- Built-in caching with configurable TTL for serverless environments
- Typed data classes for all API responses
- Specific error classes: `AuthenticationError`, `NotFoundError`, `ValidationError`, `RateLimitError`
- Full RSpec test suite with WebMock
