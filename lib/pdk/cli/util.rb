module PDK
  module CLI
    module Util
      # Ensures the calling code is being run from inside a module directory.
      #
      # @param opts [Hash] options to change the behavior of the check logic.
      # @option opts [Boolean] :check_module_layout Set to true to check for
      #   stardard module folder layout if the module does not contain
      #   a metadata.json file.
      #
      # @raise [PDK::CLI::ExitWithError] if the current directory does not
      #   contain a Puppet module.
      def ensure_in_module!(opts = {})
        return unless PDK::Util.module_root.nil?
        return if opts[:check_module_layout] && PDK::Util.in_module_root?

        message = opts.fetch(:message, _('This command must be run from inside a valid module (no metadata.json found).'))
        raise PDK::CLI::ExitWithError.new(message, opts)
      end
      module_function :ensure_in_module!

      def spinner_opts_for_platform
        windows_opts = {
          success_mark: '*',
          error_mark: 'X',
        }

        return windows_opts if Gem.win_platform?
        {}
      end
      module_function :spinner_opts_for_platform

      def prompt_for_yes(question_text, opts = {})
        prompt = opts[:prompt] || TTY::Prompt.new(help_color: :cyan)
        validator = proc { |value| [true, false].include?(value) || value =~ %r{\A(?:yes|y|no|n)\Z}i }
        response = nil

        begin
          response = prompt.yes?(question_text) do |q|
            q.default opts[:default] unless opts[:default].nil?
            q.validate(validator, _('Answer "Y" to continue or "n" to cancel.'))
          end
        rescue TTY::Prompt::Reader::InputInterrupt
          PDK.logger.info opts[:cancel_message] if opts[:cancel_message]
        end

        response
      end
      module_function :prompt_for_yes

      def interactive?
        return false if PDK.logger.debug?
        return !ENV['PDK_FRONTEND'].casecmp('noninteractive').zero? if ENV['PDK_FRONTEND']
        return false unless $stderr.isatty

        true
      end
      module_function :interactive?

      def module_version_check
        module_pdk_ver = PDK::Util.module_pdk_version

        # This means the module does not have a pdk-version tag in the metadata.json
        # and will require a pdk convert.
        raise PDK::CLI::ExitWithError, _('This module is not PDK compatible. Run `pdk convert` to make it compatible with your version of PDK.') if module_pdk_ver.nil?

        # This checks that the version of pdk in the module's metadata is older
        # than 1.3.1, which means the module will need to run pdk convert to the
        # new templates.
        if Gem::Version.new(module_pdk_ver) < Gem::Version.new('1.3.1')
          PDK.logger.warn _('This module template is out of date. Run `pdk convert` to make it compatible with your version of PDK.')
        # This checks if the version of the installed PDK is older than the
        # version in the module's metadata, and advises the user to upgrade to
        # their install of PDK.
        elsif Gem::Version.new(PDK::VERSION) < Gem::Version.new(module_pdk_ver)
          PDK.logger.warn _('This module is compatible with a newer version of PDK. Upgrade your version of PDK to ensure compatibility.')
        # This checks if the version listed in the module's metadata is older
        # than the installed PDK, and advises the user to run pdk update.
        elsif Gem::Version.new(PDK::VERSION) > Gem::Version.new(module_pdk_ver)
          PDK.logger.warn _('This module is compatible with an older version of PDK. Run `pdk update` to update it to your version of PDK.')
        end
      end
      module_function :module_version_check

      def puppet_from_opts_or_env(opts)
        desired_puppet_version = (opts || {})[:'puppet-version'] || ENV['PDK_PUPPET_VERSION']
        desired_pe_version = (opts || {})[:'pe-version'] || ENV['PDK_PE_VERSION']

        begin
          puppet_env =
            if desired_puppet_version
              PDK::Util::PuppetVersion.find_gem_for(desired_puppet_version)
            elsif desired_pe_version
              PDK::Util::PuppetVersion.from_pe_version(desired_pe_version)
            else
              PDK::Util::PuppetVersion.from_module_metadata || PDK::Util::PuppetVersion.latest_available
            end
        rescue ArgumentError => e
          raise PDK::CLI::ExitWithError, e.message
        end

        # Notify user of what Ruby version will be used.
        PDK.logger.info(_('Using Ruby %{version}') % {
          version: puppet_env[:ruby_version],
        })

        gemset = { puppet: puppet_env[:gem_version].to_s }

        # Notify user of what gems are being activated.
        gemset.each do |gem, version|
          next if version.nil?

          PDK.logger.info(_('Using %{gem} %{version}') % {
            gem: gem.to_s.capitalize,
            version: version,
          })
        end

        {
          gemset: gemset,
          ruby_version: puppet_env[:ruby_version],
        }
      end
      module_function :puppet_from_opts_or_env

      def validate_puppet_version_opts(opts)
        puppet_ver_specs = []
        puppet_ver_specs << '--puppet-version option' if opts[:'puppet-version']
        puppet_ver_specs << 'PDK_PUPPET_VERSION environment variable' if ENV['PDK_PUPPET_VERSION'] && !ENV['PDK_PUPPET_VERSION'].empty?

        pe_ver_specs = []
        pe_ver_specs << '--pe-version option' if opts[:'pe-version']
        pe_ver_specs << 'PDK_PE_VERSION environment variable' if ENV['PDK_PE_VERSION'] && !ENV['PDK_PE_VERSION'].empty?

        puppet_ver_specs.each do |pup_ver_spec|
          next if pe_ver_specs.empty?

          offending = [pup_ver_spec, pe_ver_specs[0]].sort

          raise PDK::CLI::ExitWithError, _('You cannot specify a %{first} and %{second} at the same time.') % {
            first: offending[0],
            second: offending[1],
          }
        end

        if puppet_ver_specs.size == 2
          warning_str = 'Puppet version option from command line: "--puppet-version=%{pup_ver_opt}" '
          warning_str += 'overrides value from environment: "PDK_PUPPET_VERSION=%{pup_ver_env}". You should not specify both.'

          PDK.logger.warn(_(warning_str) % {
            pup_ver_opt: opts[:'puppet-version'],
            pup_ver_env: ENV['PDK_PUPPET_VERSION'],
          })
        elsif pe_ver_specs.size == 2
          warning_str = 'Puppet Enterprise version option from command line: "--pe-version=%{pe_ver_opt}" '
          warning_str += 'overrides value from environment: "PDK_PE_VERSION=%{pe_ver_env}". You should not specify both.'

          PDK.logger.warn(_(warning_str) % {
            pup_ver_opt: opts[:'pe-version'],
            pup_ver_env: ENV['PDK_PE_VERSION'],
          })
        end
      end
      module_function :validate_puppet_version_opts
    end
  end
end
