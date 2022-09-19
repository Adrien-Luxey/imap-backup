require "imap/backup/mirror"

module Imap::Backup
  class CLI::Mirror < Thor
    include Thor::Actions
    include CLI::Helpers

    attr_reader :destination_email
    attr_reader :destination_prefix
    attr_reader :config_path
    attr_reader :source_email
    attr_reader :source_prefix

    def initialize(
      source_email,
      destination_email,
      config: nil,
      destination_prefix: "",
      source_prefix: ""
    )
      super([])
      @destination_email = destination_email
      @destination_prefix = destination_prefix
      @config_path = config
      @source_email = source_email
      @source_prefix = source_prefix
    end

    no_commands do
      def run
        check_accounts!
        warn_if_source_account_is_not_in_mirror_mode

        CLI::Backup.new(config: config_path, accounts: source_email).run

        folders.each do |serializer, folder|
          Mirror.new(serializer, folder).run
        end
      end

      def check_accounts!
        if destination_email == source_email
          raise "Source and destination accounts cannot be the same!"
        end

        raise "Account '#{destination_email}' does not exist" if !destination_account

        raise "Account '#{source_email}' does not exist" if !source_account
      end

      def warn_if_source_account_is_not_in_mirror_mode
        return if source_account.mirror_mode

        message =
          "The account '#{source_account.username}' " \
          "is not set up to make mirror backups"
        Logger.logger.info message
      end

      def config
        @config = load_config(config: config_path)
      end

      def destination_account
        config.accounts.find { |a| a.username == destination_email }
      end

      def folders
        return enum_for(:folders) if !block_given?

        glob = File.join(source_local_path, "**", "*.imap")
        Pathname.glob(glob) do |path|
          name = source_folder_name(path)
          serializer = Serializer.new(source_local_path, name)
          folder = folder_for(name)
          yield serializer, folder
        end
      end

      def folder_for(source_folder)
        no_source_prefix =
          if source_prefix != "" && source_folder.start_with?(source_prefix)
            source_folder.delete_prefix(source_prefix)
          else
            source_folder.to_s
          end

        with_destination_prefix =
          if destination_prefix && destination_prefix != ""
            destination_prefix + no_source_prefix
          else
            no_source_prefix
          end

        Account::Folder.new(
          destination_account.connection,
          with_destination_prefix
        )
      end

      def source_local_path
        source_account.local_path
      end

      def source_account
        config.accounts.find { |a| a.username == source_email }
      end

      def source_folder_name(imap_pathname)
        base = Pathname.new(source_local_path)
        imap_name = imap_pathname.relative_path_from(base).to_s
        dir = File.dirname(imap_name)
        stripped = File.basename(imap_name, ".imap")
        if dir == "."
          stripped
        else
          File.join(dir, stripped)
        end
      end
    end
  end
end
