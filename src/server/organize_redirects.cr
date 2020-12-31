class Crem::App
  def organize_redirects!
    unless @config.no_root.unwrap
      @redirects << Crem::Redirect.new("", @config.root.unwrap, Crem::Redirect::Status::Success)
      @redirects << Crem::Redirect.new("/", @config.root.unwrap, Crem::Redirect::Status::Success)
    end

    @redirects = @redirects + @config.redirects.unwrap

    duplicates = @redirects.map(&.from).tally.select { |k, v| v > 1 }

    unless duplicates.empty?
      longest = duplicates.map(&.[0]).max_by(&.size).size
      puts("You have duplicate redirects defined:".colorize(:red))
      duplicates.each do |dup, q|
        tos = redirects.select(&.from.==(dup)).map(&.to)
        puts("  '#{dup}' #{" " * (longest - dup.size)}-> #{tos.join(", ")}".colorize(:yellow))
      end

      unless @config.no_root.unwrap
        if duplicates.keys.includes?("") || duplicates.keys.includes?("/")
          puts
          puts("It looks like you may have a conflict with the default root helper.".colorize(:yellow))
          puts("If you're defining root redirects in your config file, you probably want to set the no_root option to true.".colorize(:yellow))
        end
      end

      exit(1)
    end
  end
end
