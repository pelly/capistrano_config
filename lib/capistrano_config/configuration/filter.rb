require "capistrano_config/configuration"
require "capistrano_config/configuration/empty_filter"
require "capistrano_config/configuration/host_filter"
require "capistrano_config/configuration/null_filter"
require "capistrano_config/configuration/role_filter"

module CapistranoConfig
  class Configuration
    class Filter
      def initialize(type, values=nil)
        raise "Invalid filter type #{type}" unless %i(host role).include? type
        av = Array(values)
        @strategy = if av.empty? then EmptyFilter.new
                    elsif av.include?(:all) || av.include?("all") then NullFilter.new
                    elsif type == :host then HostFilter.new(values)
                    elsif type == :role then RoleFilter.new(values)
                    else NullFilter.new
                    end
      end

      def filter(servers)
        @strategy.filter servers
      end
    end
  end
end
