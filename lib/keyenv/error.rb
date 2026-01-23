# frozen_string_literal: true

module KeyEnv
  # Base error class for KeyEnv API errors.
  class Error < StandardError
    # @return [Integer] HTTP status code
    attr_reader :status

    # @return [String, nil] Error code from API
    attr_reader :code

    # @return [Hash, nil] Additional error details
    attr_reader :details

    # @return [String] Original error message
    attr_reader :original_message

    # @param message [String] Error message
    # @param status [Integer] HTTP status code (default: 0)
    # @param code [String, nil] Error code from API
    # @param details [Hash, nil] Additional error details
    def initialize(message, status: 0, code: nil, details: nil)
      @original_message = message
      @status = status
      @code = code
      @details = details || {}
      super(message)
    end

    def to_s
      if status.positive?
        "KeyEnvError(#{status}): #{@original_message}"
      else
        "KeyEnvError: #{@original_message}"
      end
    end
  end

  # Raised when authentication fails.
  class AuthenticationError < Error; end

  # Raised when a resource is not found.
  class NotFoundError < Error; end

  # Raised when the request is invalid.
  class ValidationError < Error; end

  # Raised when rate limited.
  class RateLimitError < Error; end

  # Raised on network/connection errors.
  class ConnectionError < Error; end

  # Raised on request timeout.
  class TimeoutError < Error; end
end
