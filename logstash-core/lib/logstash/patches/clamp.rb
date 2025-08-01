# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

require 'clamp'
require 'logstash/environment'
require 'logstash/deprecation_message'

module Clamp
  module Attribute
    class Instance
      def default_from_environment
        # we don't want uncontrolled var injection from the environment
        # since we're establishing that settings can be pulled from only three places:
        # 1. default settings
        # 2. yaml file
        # 3. cli arguments
      end
    end
  end

  module Option
    module Declaration
      def deprecated_option(switches, type, description, opts = {})
        Option::Definition.new(switches, type, description, opts).tap do |option|
          declared_options << option
          block ||= option.default_conversion_block
          define_deprecated_accessors_for(option, opts, &block)
        end
      end
    end

    module StrictDeclaration
      include Clamp::Attribute::Declaration
      include LogStash::Util::Loggable

      # Instead of letting Clamp set up accessors for the options
      # weŕe going to tightly controlling them through
      # LogStash::SETTINGS
      def define_simple_writer_for(option, &block)
        LogStash::SETTINGS.get(option.attribute_name)
        define_method(option.write_method) do |value|
          value = instance_exec(value, &block) if block
          LogStash::SETTINGS.set_value(option.attribute_name, value)
        end
      end

      def define_reader_for(option)
        define_method(option.read_method) do
          LogStash::SETTINGS.get_value(option.attribute_name)
        end
      end

      def define_appender_for(option)
        define_method(option.append_method) do |value|
          LogStash::SETTINGS.get_value(option.attribute_name) << value
        end
      end

      def define_deprecated_accessors_for(option, opts, &block)
        define_deprecated_writer_for(option, opts, &block)
      end

      def define_deprecated_writer_for(option, opts, &block)
        define_method(option.write_method) do |value|
          new_flag = opts[:new_flag]
          new_value = opts.fetch(:new_value, value)
          passthrough = opts.fetch(:passthrough, false)
          obsoleted_version = opts[:obsoleted_version]

          dmsg = "DEPRECATION WARNING: The flag #{option.switches} has been deprecated"
          dmsg += obsoleted_version.nil? ? " and may be removed in a future release" : " and will be removed in version #{obsoleted_version}"
          dmsg += new_flag.nil? ? ".": ", please use \"--#{new_flag}=#{new_value}\" instead."

          LogStash::DeprecationMessage.instance << dmsg

          if passthrough
            LogStash::SETTINGS.set(option.attribute_name, value)
          else
            LogStash::SETTINGS.set(opts[:new_flag], opts.include?(:new_value) ? opts[:new_value] : value)
          end
        end
      end
    end

    class Definition
      # Allow boolean flags to optionally receive a true/false argument
      # to explicitly set them, i.e.
      # --long.flag.name       => sets flag to true
      # --long.flag.name true  => sets flag to true
      # --long.flag.name false => sets flag to false
      # --long.flag.name=true  => sets flag to true
      # --long.flag.name=false => sets flag to false
      def extract_value(switch, arguments)
        if flag? && (arguments.first.nil? || arguments.first.match("^-"))
          flag_set?(switch)
        else
          raise ArgumentError, Clamp.message(:no_value_provided) if arguments.empty?
          arguments.shift
        end
      end
    end
  end

  # Create a subclass of Clamp::Command that enforces the use of
  # LogStash::SETTINGS for setting validation
  class StrictCommand < Command
    class << self
      include ::Clamp::Option::StrictDeclaration
    end

    def handle_remaining_arguments
      unless remaining_arguments.empty?
        signal_usage_error "Unknown command '#{remaining_arguments.first}'"
      end
    end
  end
end
