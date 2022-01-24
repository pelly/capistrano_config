require "set"
require "capistrano_config/configuration"
require "capistrano_config/configuration/filter"

module CapistranoConfig
  class Configuration
    class Servers
      include Enumerable

      def add_host(host, properties = {})
        host = host.to_sym
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
      def add_role(role, hosts, options = {})
        options_deepcopy = Marshal.dump(options.merge(roles: role))
        Array(hosts).each { |host| add_host(host, Marshal.load(options_deepcopy)) }
      end

      # rubocop:enable Security/MarshalLoad

      def roles_for(*names)
        names = [names].flatten
        options = extract_options(names)
        s = Filter.new(:role, names).filter(servers_by_key.values)
        s.select { |server| server.select?(options) }
      end

      def role_properties_for(*rolenames, include_non_role_props:false)
        rolenames = [rolenames].flatten
        roles = rolenames.to_set
        rps = Set.new unless block_given?
        roles_for(rolenames).each do |host|
          host.roles.intersection(roles).each do |role|
            [host.properties.fetch(role)].flatten(1).each do |props|
              if block_given?
                yield host, role, props
              else
                if include_non_role_props
                  rps << (props || {}).merge(role: role, hostname: host.hostname).merge(host.non_role_properties.to_h)
                else
                  rps << (props || {}).merge(role: role, hostname: host.hostname)
                end
              end
            end
          end
        end
        block_given? ? nil : rps
      end

      def all_properties_for(*rolenames)
        role_properties_for(*rolenames, include_non_role_props:true)
      end

      def fetch_primary(role)
        hosts = roles_for([role])
        hosts.find(&:primary) || hosts.first
      end

      def each
        servers_by_key.values.each { |server| yield server }
      end

      def method_missing(symbol, *args)
        if args.empty? && server = servers_by_key[ServerKey.new(symbol.to_sym)]
          return server
        end
        super
      end

      private

      ServerKey = Struct.new(:hostname, :port) do
        def ==(other)
          hostname == other.hostname && port == other.port
        end

        def hash
          [hostname, port].hash
        end
      end

      def servers_by_key
        @servers_by_key ||= {}
      end

      def extract_options(array)
        array.last.is_a?(::Hash) ? array.pop : {}
      end
    end
  end
end
