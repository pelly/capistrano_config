require "spec_helper"

module CapistranoConfig
  describe Configuration do
    let(:config) { Configuration.new }
    let(:servers) { stub }

    describe ".new" do
      it "accepts initial hash" do
        configuration = described_class.new(custom: "value")
        expect(configuration.fetch(:custom)).to eq("value")
      end
    end

    describe ".env" do
      it "is a global accessor to a single instance" do
        Configuration.env.set(:test, true)
        expect(Configuration.env.fetch(:test)).to be_truthy
      end
    end

    describe ".reset!" do
      it "blows away the existing `env` and creates a new one" do
        old_env = Configuration.env
        Configuration.reset!
        expect(Configuration.env).not_to be old_env
      end
    end

    describe "roles" do
      context "adding a role" do
        subject { config.role(:app, %w{server1 server2}) }

        before do
          Configuration::Servers.expects(:new).returns(servers)
          servers.expects(:add_role).with(:app, %w{server1 server2}, {})
        end

        it "adds the role" do
          expect(subject)
        end
      end
    end

    describe "setting and fetching via missing methods" do
      context "set via method_name=" do
        subject { config.fetch(:some_val, :default) }

        it "sets the value" do
          config.some_val = :value
          expect(subject).to eq :value
        end
      end

      context "get via method_name" do
        it "gets a value via method name" do
          config.set(:some_val, :value)
          expect(config.some_val).to eq(:value)
        end

        it "returns nil when no value was set" do
          expect(config.some_val).to be_nil
        end
      end
    end
    describe "setting and fetching" do
      subject { config.fetch(:key, :default) }

      context "set" do
        it "sets by value" do
          config.set(:key, :value)
          expect(subject).to eq :value
        end

        it "sets by block" do
          config.set(:key) { :value }
          expect(subject).to eq :value
        end

        it "raises an exception when given both a value and block" do
          expect { config.set(:key, :value) { :value } }.to raise_error(CapistranoConfig::ValidationError)
        end
      end

      context "set_if_empty" do
        it "sets by value when none is present" do
          config.set_if_empty(:key, :value)
          expect(subject).to eq :value
        end

        it "sets by block when none is present" do
          config.set_if_empty(:key) { :value }
          expect(subject).to eq :value
        end

        it "does not overwrite existing values" do
          config.set(:key, :value)
          config.set_if_empty(:key, :update)
          config.set_if_empty(:key) { :update }
          expect(subject).to eq :value
        end
      end

      context "value is not set" do
        it "returns the default value" do
          expect(subject).to eq :default
        end
      end

      context "value is a proc" do
        subject { config.fetch(:key, proc { :proc }) }
        it "calls the proc" do
          expect(subject).to eq :proc
        end
      end

      context "value is a lambda" do
        subject { config.fetch(:key, -> { :lambda }) }
        it "calls the lambda" do
          expect(subject).to eq :lambda
        end
      end

      context "value inside proc inside a proc" do
        subject { config.fetch(:key, proc { proc { "some value" } }) }
        it "calls all procs and lambdas" do
          expect(subject).to eq "some value"
        end
      end

      context "value inside lambda inside a lambda" do
        subject { config.fetch(:key, -> { -> { "some value" } }) }
        it "calls all procs and lambdas" do
          expect(subject).to eq "some value"
        end
      end

      context "value inside lambda inside a proc" do
        subject { config.fetch(:key, proc { -> { "some value" } }) }
        it "calls all procs and lambdas" do
          expect(subject).to eq "some value"
        end
      end

      context "value inside proc inside a lambda" do
        subject { config.fetch(:key, -> { proc { "some value" } }) }
        it "calls all procs and lambdas" do
          expect(subject).to eq "some value"
        end
      end

      context "lambda with parameters" do
        subject { config.fetch(:key, ->(c) { c }).call(42) }
        it "is returned as a lambda" do
          expect(subject).to eq 42
        end
      end

      context "block is passed to fetch" do
        subject { config.fetch(:key, :default) { raise "we need this!" } }

        it "returns the block value" do
          expect { subject }.to raise_error(RuntimeError)
        end
      end

      context "validations" do
        before do
          config.validate :key do |_, value|
            raise CapistranoConfig::ValidationError unless value.length > 3
          end
        end

        it "validates string without error" do
          config.set(:key, "longer_value")
        end

        it "validates block without error" do
          config.set(:key) { "longer_value" }
          expect(config.fetch(:key)).to eq "longer_value"
        end

        it "validates lambda without error" do
          config.set :key, -> { "longer_value" }
          expect(config.fetch(:key)).to eq "longer_value"
        end

        it "raises an exception on invalid string" do
          expect { config.set(:key, "sho") }.to raise_error(CapistranoConfig::ValidationError)
        end

        it "raises an exception on invalid string provided by block" do
          config.set(:key) { "sho" }
          expect { config.fetch(:key) }.to raise_error(CapistranoConfig::ValidationError)
        end

        it "raises an exception on invalid string provided by lambda" do
          config.set :key, -> { "sho" }
          expect { config.fetch(:key) }.to raise_error(CapistranoConfig::ValidationError)
        end
      end

      context "appending" do
        subject { config.append(:linked_dirs, "vendor/bundle", "tmp") }

        it "returns appended value" do
          expect(subject).to eq ["vendor/bundle", "tmp"]
        end

        context "on non-array variable" do
          before { config.set(:linked_dirs, "string") }
          subject { config.append(:linked_dirs, "vendor/bundle") }

          it "returns appended value" do
            expect(subject).to eq ["string", "vendor/bundle"]
          end
        end
      end

      context "removing" do
        before :each do
          config.set(:linked_dirs, ["vendor/bundle", "tmp"])
        end

        subject { config.remove(:linked_dirs, "vendor/bundle") }

        it "returns without removed value" do
          expect(subject).to eq ["tmp"]
        end

        context "on non-array variable" do
          before { config.set(:linked_dirs, "string") }

          context "when removing same value" do
            subject { config.remove(:linked_dirs, "string") }

            it "returns without removed value" do
              expect(subject).to eq []
            end
          end

          context "when removing different value" do
            subject { config.remove(:linked_dirs, "othervalue") }

            it "returns without removed value" do
              expect(subject).to eq ["string"]
            end
          end
        end
      end
    end

    describe "keys" do
      subject { config.keys }

      before do
        config.set(:key1, :value1)
        config.set(:key2, :value2)
      end

      it "returns all set keys" do
        expect(subject).to match_array %i(key1 key2)
      end
    end

    describe "deleting" do
      before do
        config.set(:key, :value)
      end

      it "deletes the value" do
        config.delete(:key)
        expect(config.fetch(:key)).to be_nil
      end
    end

    describe "asking" do
      let(:question) { stub }
      let(:options) { {} }

      before do
        Configuration::Question.expects(:new).with(:branch, :default, options)
                               .returns(question)
      end

      it "prompts for the value when fetching" do
        config.ask(:branch, :default, options)
        expect(config.fetch(:branch)).to eq question
      end
    end

    describe "setting the backend" do
      it "by default, is SSHKit" do
        expect(config.backend).to eq SSHKit
      end

      it "can be set to another class" do
        config.backend = :test
        expect(config.backend).to eq :test
      end

      describe "ssh_options for Netssh" do
        it "merges them with the :ssh_options variable" do
          config.set :format, :pretty
          config.set :log_level, :debug
          config.set :ssh_options, user: "albert"
          SSHKit::Backend::Netssh.configure { |ssh| ssh.ssh_options = { password: "einstein" } }
          config.configure_backend

          expect(
            config.backend.config.backend.config.ssh_options
          ).to include(user: "albert", password: "einstein")
        end
      end
    end

    describe "dry_run?" do
      it "returns false when using default backend" do
        expect(config.dry_run?).to eq(false)
      end

      it "returns true when using printer backend" do
        config.set :sshkit_backend, SSHKit::Backend::Printer

        expect(config.dry_run?).to eq(true)
      end
    end

    describe "custom filtering" do
      it "accepts a custom filter object" do
        filter = Object.new

        def filter.filter(servers)
          servers
        end

        config.add_filter(filter)
      end

      it "accepts a custom filter as a block" do
        config.add_filter { |servers| servers }
      end

      it "raises an error if passed a block and an object" do
        filter = Object.new

        def filter.filter(servers)
          servers
        end

        expect { config.add_filter(filter) { |servers| servers } }.to raise_error(ArgumentError)
      end

      it "raises an error if the filter lacks a filter method" do
        filter = Object.new
        expect { config.add_filter(filter) }.to raise_error(TypeError)
      end

      it "calls the filter method of a custom filter" do
        ENV.delete "ROLES"
        ENV.delete "HOSTS"

        servers = Configuration::Servers.new

        servers.add_host("test1")
        servers.add_host("test2")
        servers.add_host("test3")

        filtered_servers = servers.take(2)

        filter = mock("custom filter")
        filter.expects(:filter)
              .with { |subset| subset.is_a? Configuration::Servers }
              .returns(filtered_servers)

        config.add_filter(filter)
        expect(config.filter(servers)).to eq(filtered_servers)
      end
    end

    describe "merging behavior" do
      subject { Configuration.new }

      describe "non-cacheing delayed values" do
        before do
          subject.other_val = "original immediate setting"
          subject.delayed_val = ->() { "DELAYED EVAL of #{subject.fetch(:other_val)}" }
        end

        it "re-evaluates non-cached delayed values using the newly merged in dependents" do
          expect(subject.delayed_val).to eq("DELAYED EVAL of original immediate setting")
          subject.merge!({ other_val: -> () { "new delayed val" } })
          expect(subject.fetch(:delayed_val)).to eq("DELAYED EVAL of new delayed val")
        end
      end
    end

    describe "#merge_properties" do
      subject { Configuration.new }
      before do
        subject.fluctuates = "this will change"
        subject.base_val = "base val"
        subject.server :s1, roles: %w{r1 r2}, s1_prop: "s1 based prop", r1: { r1_prop: "s1 r1 prop", fluctuates: "s1 r1" }, r2: { r2_prop: "s1 r2 prop", fluctuates: "s1 r2" }
        expect(subject.fluctuates).to eq("this will change")
        subject.merge_properties(host: :s1, role: :r1)
      end

      it "adds role properties" do
        expect(subject[:fluctuates]).to eq("s1 r1")
        expect(subject[:r1_prop]).to eq("s1 r1 prop")
      end

      it "adds host properties" do
        expect(subject[:s1_prop]).to eq("s1 based prop")
      end

      it "keeps existing properties not overridden" do
        expect(subject[:base_val]).to eq("base val")
      end

      it "doesn't merge in other role properties" do
        expect(subject[:r2_prop]).to be_nil
      end

      describe "when no role specified" do
        it "doesn't merge any role-based properties"
      end

    end

    describe "#merge_properties corner cases" do
      subject { Configuration.new }
      before do
        subject.server :s1, roles: %w{role1}, some_val: "s1", role1: { role1_key1: "role1 val 1" }
      end

      it "raises an error if you request to merge properties from a role that doesn't exist" do
        expect { subject.merge_properties host: :s1, role: :non_existant }.to raise_error(RuntimeError, "Role :non_existant doesn't exist for :s1")
      end
    end

    describe "#merge_properties behavior with lambdas / procs" do
      subject { Configuration.new }
      before do
        subject.fluctuates = "this will change"
        subject.proc_property = -> () { "proc property value of fluctuates: #{subject.fluctuates}" }
        subject.server :s1, roles: %w{r1}, r1: {fluctuates: "s1 r1"}
        expect(subject.proc_property).to eq("proc property value of fluctuates: this will change")
        subject.merge_properties(host: :s1, role: :r1)
      end

      it "accesses roles through the server method" do
        expect(subject.server(:s1).has_role?("r1")).to be_truthy
      end

      it "re-evaluates the proc to incorporate any changes" do
        expect(subject.proc_property).to eq("proc property value of fluctuates: s1 r1")
      end
    end

  end
end
