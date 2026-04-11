require "../extensions/log"

module LightningImage
  class AllowList
    getter allow_list_regexes : Array(Regex) = [] of Regex

    class AllowListFileNotFoundError < Exception; end

    def initialize(allow_list_file_path : String)
      raise AllowListFileNotFoundError.new("Allow list file not found: #{allow_list_file_path}") if !File.exists?(allow_list_file_path)

      Log.debug("Loading allow list from #{allow_list_file_path}")

      @allow_list_regexes = File.read_lines(allow_list_file_path)
                                .reject(&.blank?)
                                .reject { |line| line.strip.starts_with?("#") }
                                .map { |line| Regex.new(line.strip) }
      Log.debug("Allow list loaded: #{@allow_list_regexes.inspect}")
    end

    def allowed?(url : String)
      return true if @allow_list_regexes.empty?

      @allow_list_regexes.any? { |allowed_url_regex| url =~ allowed_url_regex }
    end
  end

  class AllowEverything < AllowList
    def initialize; end

    def allowed?(url : String); true; end
  end
end
