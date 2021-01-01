class Crem::App
  def organize_static_dirs!
    @static_dirs = @config.static_dirs.unwrap

    duplicates = @static_dirs.tally.select { |k, v| v > 1 }

    unless duplicates.empty?
      puts("Warning: You have duplicate redirects defined:".colorize(:yellow))
      duplicates.each do |dup, q|
        puts("  '#{dup}'\n".colorize(:yellow))
      end
    end
  end
end
