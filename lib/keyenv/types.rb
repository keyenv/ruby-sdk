# frozen_string_literal: true

module KeyEnv
  # User or service token info.
  class User
    attr_reader :id, :email, :name, :clerk_id, :avatar_url, :auth_type,
                :team_id, :project_ids, :scopes, :created_at

    def initialize(data)
      @id = data["id"]
      @email = data["email"]
      @name = data["name"]
      @clerk_id = data["clerk_id"]
      @avatar_url = data["avatar_url"]
      @auth_type = data["auth_type"]
      @team_id = data["team_id"]
      @project_ids = data["project_ids"]
      @scopes = data["scopes"]
      @created_at = data["created_at"]
    end
  end

  # Project.
  class Project
    attr_reader :id, :team_id, :name, :slug, :description, :created_at

    def initialize(data)
      @id = data["id"]
      @team_id = data["team_id"]
      @name = data["name"]
      @slug = data["slug"]
      @description = data["description"]
      @created_at = data["created_at"]
    end
  end

  # Environment.
  class Environment
    attr_reader :id, :project_id, :name, :inherits_from, :created_at

    def initialize(data)
      @id = data["id"]
      @project_id = data["project_id"]
      @name = data["name"]
      @inherits_from = data["inherits_from"]
      @created_at = data["created_at"]
    end
  end

  # Project with environments.
  class ProjectWithEnvironments < Project
    attr_reader :environments

    def initialize(data)
      super(data)
      envs = data["environments"] || []
      @environments = envs.map { |e| Environment.new(e) }
    end
  end

  # Secret (without value).
  class Secret
    attr_reader :id, :environment_id, :key, :type, :version,
                :description, :created_at, :updated_at

    def initialize(data)
      @id = data["id"]
      @environment_id = data["environment_id"]
      @key = data["key"]
      @type = data["type"] || "string"
      @version = data["version"]
      @description = data["description"]
      @created_at = data["created_at"]
      @updated_at = data["updated_at"]
    end
  end

  # Secret with decrypted value.
  class SecretWithValue < Secret
    attr_reader :value, :inherited_from

    def initialize(data)
      super(data)
      @value = data["value"] || ""
      @inherited_from = data["inherited_from"]
    end
  end

  # Secret history entry.
  class SecretHistory
    attr_reader :id, :secret_id, :value, :version, :changed_by, :changed_at

    def initialize(data)
      @id = data["id"]
      @secret_id = data["secret_id"]
      @value = data["value"]
      @version = data["version"]
      @changed_by = data["changed_by"]
      @changed_at = data["changed_at"]
    end
  end

  # Bulk import request item.
  class BulkSecretItem
    attr_reader :key, :value, :description

    def initialize(key:, value:, description: nil)
      @key = key
      @value = value
      @description = description
    end

    def to_h
      h = { "key" => key, "value" => value }
      h["description"] = description if description
      h
    end
  end

  # Bulk import result.
  class BulkImportResult
    attr_reader :created, :updated, :skipped

    def initialize(data)
      @created = data["created"] || 0
      @updated = data["updated"] || 0
      @skipped = data["skipped"] || 0
    end
  end

  # Environment permission for a user.
  class EnvironmentPermission
    attr_reader :id, :environment_id, :user_id, :role, :user_email,
                :user_name, :granted_by, :created_at, :updated_at

    def initialize(data)
      @id = data["id"]
      @environment_id = data["environment_id"]
      @user_id = data["user_id"]
      @role = data["role"]
      @user_email = data["user_email"]
      @user_name = data["user_name"]
      @granted_by = data["granted_by"]
      @created_at = data["created_at"] || ""
      @updated_at = data["updated_at"] || ""
    end
  end

  # User's own permission for an environment.
  class MyPermission
    attr_reader :environment_id, :environment_name, :role,
                :can_read, :can_write, :can_admin

    def initialize(data)
      @environment_id = data["environment_id"]
      @environment_name = data["environment_name"]
      @role = data["role"]
      @can_read = data["can_read"]
      @can_write = data["can_write"]
      @can_admin = data["can_admin"]
    end
  end

  # Default permission for an environment in a project.
  class ProjectDefault
    attr_reader :id, :project_id, :environment_name, :default_role, :created_at

    def initialize(data)
      @id = data["id"]
      @project_id = data["project_id"]
      @environment_name = data["environment_name"]
      @default_role = data["default_role"]
      @created_at = data["created_at"] || ""
    end
  end
end
