# Copyright (c) 2008-2009, ActiveRain Corp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of ActiveRain Corp. nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY ActiveRain Corp. "AS IS" AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL ActiveRain Corp. OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 'open-uri'
require 'cgi'
require 'logger'

module RubyEnom
  ALLOWED_TLDS = %w(com net org)
  COMMANDS_DEFAULT_OPTIONS = {
    :check => {},
    :purchase => {}
  }

  def self.allow_any_tld
    @@allow_any_tld
  end

  def self.allow_any_tld=(value)
    @@allow_any_tld = value
  end
  self.allow_any_tld = false

  def self.default_logger
    @@default_logger
  end

  def self.default_logger=(value)
    @@default_logger = value
  end
  self.default_logger = Logger.new(STDOUT)

  class Error < RuntimeError; end
  class DomainError < Error; end
  class CommandError < Error; end
  class ConfigurationError < Error; end

  module Util
    def self.get_sld_and_tld_from_domain(domain, recognized_tlds = ALLOWED_TLDS)
      tld = recognized_tlds.detect do |t|
        domain =~ /\.#{t.tr('.', '\.')}$/
      end

      if tld
        sld = /([^.]+)\.#{tld.tr('.', '\.')}$/.match(domain)[1]
      else
        raise DomainError, "Specified domain (#{domain}) is not on the list of recognized TLDs: #{recognized_tlds.join(", ")}."
      end

      [sld, tld]
    end
  end

  class Connection
    attr_reader :username, :password, :url

    def initialize(username, password, url)
      @username = username
      @password = password
      @url      = url
    end

    # Define a public method for each command as a nice
    # wrapper for the +execute+ private method.
    #
    # It returns a Response object which is a simple Hash
    # with the adition of some handy methods.
    COMMANDS_DEFAULT_OPTIONS.each_key do |c|
      define_method(c) do |options|
        execute(c, options)
      end
    end

    def domain_available?(domain)
      sld, tld = get_sld_and_tld_from_domain(domain)
      resp = check(:sld => sld, :tld => tld)
      if resp.has_errors?
        raise CommandError, "The command returned errors: #{resp.errors.join(". ")}"
      end
      resp.is_available?
    end

    private

      def execute(cmd, options = {})
        logger.info "About to execute eNom command '#{cmd}' with options '#{options.inspect}'"
        opts = full_options(cmd, options)
        validate_options(options)
        open(make_url(opts)) do |stream|
          resp = stream.read
          logger.debug "Response from eNom: #{resp.inspect}"
          response_class_for(cmd)[Hash.from_xml(resp)["interface_response"]]
        end
      end

      def validate_options(options)
        if tld = options[:tld]
          unless is_a_valid_tld?(tld)
            raise DomainError, "Specified TLD (#{tld}) is not on the list of suported TLDs: #{ALLOWED_TLDS.join(", ")}."
          end
        end
      end

      def full_options(cmd, options)
        default_command_options(cmd).merge(options)
      end

      def make_url(options = {})
        return @url if options.empty?
        parameters = options.map {|k, v| CGI.escape(k.to_s) + "=" + CGI.escape(v.to_s)}.join('&')
        @url + "?" + parameters
      end

      def command_options(cmd)
        {:command => cmd}.merge(COMMANDS_DEFAULT_OPTIONS[cmd])
      end

      def required_options
        {:uid => username, :pw => password, :responsetype => "xml"}
      end

      def default_command_options(cmd)
        required_options.merge(command_options(cmd))
      end

      def response_class_for(cmd)
        COMMANDS_RESPONSE_CLASSES[cmd] || Response
      end

      def get_sld_and_tld_from_domain(domain)
        if allow_any_tld?
          raise ConfigurationError, "You need to enable TLD validation (RubyEnom.allow_any_tld = false) to be able to use fuzzy domains"
        end
        RubyEnom::Util.get_sld_and_tld_from_domain(domain, ALLOWED_TLDS)
      end

      def is_a_valid_tld?(tld)
        allow_any_tld? || ALLOWED_TLDS.include?(tld)
      end

      def allow_any_tld?
        RubyEnom.allow_any_tld
      end

      def logger
        RubyEnom.default_logger
      end
  end

  # Response objects are simple hashes with the adition of some handy methods
  class Response < Hash

    # Return an array with the error messages
    def errors
      err_count = self["ErrCount"].to_i
      (1..err_count).map {|err| self["errors"]["Err#{err}"]}
    end

    def has_errors?
      !errors.empty?
    end
  end

  # Response adding special methods for check command
  class CheckResponse < Response
    DOMAIN_AVAILABLE_CODE = 210

    def is_available?
      self["RRPCode"].to_i == DOMAIN_AVAILABLE_CODE
    end
  end

  COMMANDS_RESPONSE_CLASSES = {
    :check => CheckResponse
  }
end
