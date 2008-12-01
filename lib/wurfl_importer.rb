require 'ar-extensions'
require 'wurfl_device'
require 'benchmark'

# The WURFL Importer is used to extract a bare minimum if information
# needed by Dynamime from WURFL compatible files into the database.
# It basically reads and parses the XML files, builds the device tree
# and dumps a list of UserAgents, Browsers and HardwarePlatforms matching
# the specified filter condition into the database.
#
# ==Usage:
# simple: initialise, then read, then store.
#
#     importer = WurflImporter.new('my-logfile.log')
#     importer.read('data/wurfl.xml') { puts '.' }
#     importer.read('data/wurfl-patch-1.xml') # as many patches as you want...
#     importer.store do |device|
#       if device[:has_pointing_device] == 'true' and device[:vendor_name] == 'nokia'
#         device[:foo_capability] = 'bar'
#         true
#       else
#         false
#       end
#     end

class WurflImporter
  # A list of exceptions that occured during import. Might become handy within a rake task.
  attr_accessor :exceptions

  # Can be set to an Array of name-regexp pairs. The regexps are matched against the ID of
  # a device record. If any one matches, the 'view_platform' attribute of the associated
  # UserAgent record will be set to the name. Might become handy when dealing with large
  # numbers of user agents and small numbers ov view mime types.
  attr_accessor :type_map

  # Initialises the importer, taking an optional logfile path.
  # You can also later specify a logger using WurflImporter#logger.
  # By default, no logging is performed on import.
  def initialize(logfile_path=nil)
    if logfile_path
      ar_logger = Logger.new(logfile_path)
      ar_logger.level = Logger::INFO
      ActiveRecord::Base.logger = ar_logger
    end
  end

  # Takes a logger to be used to log ActiveRecors related stuff during import.
  def logger=(lggr)
    ActiveRecord::Base.logger = lggr
  end

  # Reads the specified WURFL compatible file. If you want to read a WURFL file
  # and multiple patch files, you should first read the "big one" and the patch
  # files thereafter.
  # This method uses simple regular expressions to parse the file, it does not
  # really parse the XML. This means, the file should be formatted nicely in
  # the same way as the original WURFL file. This will change in the future.
  # You can specify a progress handler block that will be called each time a new
  # record is read.
  def read(wurfl_file, &progress_handler)
    progress = 0
    raise "File does not exist: #{wurfl_file}" unless File.exists?(wurfl_file)
    File.open(wurfl_file) do |file|
      file.each_line do |line|
        if line =~ /<device id="([^"]*)" user_agent="([^"]*)" fall_back="([^"]*)"/
          view_platform, user_agent, fall_back = $1, $2, $3
          view_platform = view_platform.gsub(/\./, '_').gsub(/^(\d+)/, 'a\1').downcase
          user_agent    = user_agent.gsub('\\', '/')
          fall_back     = fall_back.gsub(/\./, '_').gsub(/^(\d+)/, 'a\1').downcase
          @cur_device   = WurflDevice.new(view_platform, user_agent, fall_back)
          progress_handler.call(progress += 1) if block_given?
        elsif line =~ /<capability name="([^"]*)" value="([^"]*)"/
          @cur_device[$1] = $2
        end
      end
    end
  end

  # Stores browsers, hardware platforms and user agents into the database
  # after filtering them using a custom filter. If no block is given,
  # all records will be imported.
  # The block receives a reference to the currently evaluated device and you
  # are free (and even encouraged ;-))to modify the device record at that point.
  # You can specify a chunk size that determines the number of records loaded
  # simultaneously into the DB via AR-Extensions' import method.
  def store(chunk_size=500, &filter)
    filter = proc {|device| true } unless block_given?
    store_browsers_and_platforms(chunk_size, &filter)

    browsers     = Browser.find(:all, :select => 'id, name').inject({}){|hsh, val| hsh[val.name] = val.id; hsh }
    platforms    = HardwarePlatform.find(:all, :select => 'id, name').inject({}){|hsh, val| hsh[val.name] = val.id; hsh }
    @user_agents = []
    @exceptions  = []
    @chunk_no    = 0

    WurflDevice.devices.each do |index, device|
      if filter.call(device)
        name = "#{device[:brand_name]} #{device[:model_name]}"

        if browsers[device[:mobile_browser]] and platforms[name]
          @user_agents << UserAgent.new(:substring            => device.user_agent,
                                        :view_platform        => view_type_for(index)||index,
                                        :browser_id           => browsers[device[:mobile_browser]],
                                        :hardware_platform_id => platforms[name])
          print '.'
        end
      else
        print 's'
      end
      store_chunk if @user_agents.size == chunk_size
      $stdout.flush
    end
    store_chunk if @user_agents.size > 0
  end

  private

  def store_chunk
    if UserAgent.import(@user_agents, :validate => false)
      @user_agents = []
    end
  end

  def view_type_for(device_id)
    return nil unless @type_map
    @type_map.each do |v|
      return v.first if v.last =~ device_id
    end
    nil
  end

  def store_browsers_and_platforms(chunk_size, &filter)
    browsers  = {}
    platforms = {}
    WurflDevice.devices.each do |index, device|
      if filter.call(device)
        browsers[device[:mobile_browser]] = Browser.new(:name => device[:mobile_browser]) unless device[:mobile_browser].blank?
        name = "#{device[:brand_name]} #{device[:model_name]}"
        platforms[name] ||= HardwarePlatform.new(:name => name) unless device[:model_name].blank?
      end
    end

    Browser.import(browsers.values, :validate => true) and puts '.'
    HardwarePlatform.import(platforms.values, :validate => true) and puts '.'
  end
end

