require "set"
require "capistrano_config/configuration"
require "capistrano_config/configuration/filter"

module CapistranoConfig
  class Configuration
    class Servers
      include Enumerable

      def add_host(host, properties={})
        new_host = Server[host]
        new_host.port = properties[:port] if properties.key?(:port)
        # This matching logic must stay in sync with `Server#matches?`.
        key = ServerKey.new(new_host.hostname, new_host.port)
        existing = servers_by_key[key]
        if existing
          existing.user = new_host.user if new_host.user
          existing.with(properties)
        else
          servers_by_key[key] = new_host.with(properties)
        end
      end

      # rubocop:disable Security/MarshalLoad
      def add_role(role, hosts, options={})
        options_deepcopy = Marshal.dump(options.merge(roles: role))
        Array(hosts).each { |host| add_host(host, Marshal.load(options_deepcopy)) }
      end
      # rubocop:enable Security/MarshalLoad

      def roles_for(names)
        options = extract_options(names)
        s = Filter.new(:role, names).filter(servers_by_key.values)
        s.select { |server| server.select?(options) }
      end

      def role_properties_for(rolenames)
        roles = rolenames.to_set
        rps = Set.new unless block_given?
        roles_for(rolenames).each do |host|
          host.roles.intersection(roles).each do |role|
            [host.properties.fetch(role)].flatten(1).each do |props|
              if block_given?
                yield host, role, props
              else
                rps << (props || {}).merge(role: role, hostname: host.hostname)
              end
            end
          end
        end
        block_given? ? nil : rps
      end

      def fetch_primary(role)
        hosts = roles_for([role])
        hosts.find(&:primary) || hosts.first
      end

      def each
        servers_by_key.values.each { |server| yield server }
      end

      private

      ServerKey = Struct.new(:hostname, :port)

      def servers_by_key
        @servers_by_key ||= {}
      end

      def extract_options(array)
        array.last.is_a?(::Hash) ? array.pop : {}
      end
    end
  end
end
