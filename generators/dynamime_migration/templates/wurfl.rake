
desc 'Import data from the WURFL XML file (specified with WURFL=...); call with HELP for a more detailled explanation'
task :wurfl => :environment do
  fail "please specify at least one file to read with WURFL=file1.xml[,file2.xml,...]" unless ENV['WURFL']
  wurfls     = ENV['WURFL'].split(',')
  capability = (ENV['CAPABILITY']||'').split(',')||[:device_claims_web_support, 'true']

  importer = WurflImporter.new

  wurfls.each do |wurfl|
    puts "reading #{wurfl}:"

    importer.read(wurfl) do |i|
      print i   if i % 1000 == 0
      print '.' if i %  100 == 0
    end

    puts "read #{WurflDevice.devices.size} devices."
  end

  if ENV['ERASE_DB'] == 'true'
    Browser.delete_all
    UserAgent.delete_all
    HardwarePlatform.delete_all
  end

  puts 'inserting into DB:'

  importer.type_map = (ENV['DYNAMIME']||'').split(';').map {|r| (r =~ /^([a-z0-9_]*),\/(.*?)\/$/) ? [$1, Regexp.compile($2)] : nil }.compact
  importer.store do |device|
    device[capability[0]] == capability[1]
  end

  importer.exceptions.each do |ex|
    p ex
  end

end
