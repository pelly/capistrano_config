module CapistranoConfig
  class Configuration
    class RoleFilter
      def initialize(values)
        av = Array(values).dup
        av = av.flat_map { |v| v.is_a?(String) ? v.split(",") : v }
        @rex = regex_matcher(av)
      end

      def filter(servers)
        Array(servers).select { |s| s.is_a?(String) ? false : s.roles.any? { |r| @rex.match r } }
      end

      private

      def regex_matcher(values)
        values.map! do |v|
          case v
          when Regexp then v
          else
            vs = v.to_s
            vs =~ %r{^/(.+)/$} ? Regexp.new($1) : /^#{Regexp.quote(vs)}$/
          end
        end
        Regexp.union values
      end
    end
  end
end
