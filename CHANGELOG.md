# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1](https://github.com/keyenv/ruby-sdk/compare/v1.2.0...v1.2.1) (2026-02-07)


### Bug Fixes

* security and correctness fixes with test coverage ([462ec7f](https://github.com/keyenv/ruby-sdk/commit/462ec7f4920871c418962e8f5a14cc538a978b59))

## [1.2.0](https://github.com/keyenv/ruby-sdk/compare/v1.1.0...v1.2.0) (2026-01-26)


### Features

* add integration tests for live API testing ([c4f47c2](https://github.com/keyenv/ruby-sdk/commit/c4f47c2aa94492975a9f50ebd78287f00c2069d7))
* add tag-based release workflow for RubyGems ([736a6aa](https://github.com/keyenv/ruby-sdk/commit/736a6aa9ce190b0494e1c39c78820feba0e813a6))


### Bug Fixes

* correct error message formatting ([dbe213e](https://github.com/keyenv/ruby-sdk/commit/dbe213e2b59788a6189720e6dbb17bde03b13939))

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
