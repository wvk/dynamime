require 'ar-extensions'
require 'wurfl_device'
require 'benchmark'

class WurflImporter
  attr_accessor :exceptions, :type_map

  def initialize(logfile_path=nil)
    if logfile_path
      ar_logger = Logger.new(logfile_path)
      ar_logger.level = Logger::INFO
      ActiveRecord::Base.logger = ar_logger
    end
  end

  def logger=(lggr)
    ActiveRecord::Base.logger = lggr
  end

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

  def store(chunk_size=500, &filter)
    store_browsers_and_platforms(chunk_size, &filter)

    browsers     = Browser.find(:all, :select => 'id,name').inject({}){|hsh, val| hsh[val.name] = val.id; hsh }
    platforms    = HardwarePlatform.find(:all, :select => 'id,name').inject({}){|hsh, val| hsh[val.name] = val.id; hsh }
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

  def store_chunk
    if UserAgent.import(@user_agents, :validate => false)
      @user_agents = []
    end
  end

  def view_type_for(device_id)
    @type_map.each do |v|
      return v[0] if v[1] =~ device_id
    end
    nil
  end
end

