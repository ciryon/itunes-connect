require "digest/md5"
require "tempfile"
require "yaml"
require "zlib"
require "rubygems"
require "httpclient"
require "nokogiri"

module AppStore

  # Abstracts the iTunes Connect website.
  # Implementation inspired by
  # http://code.google.com/p/itunes-connect-scraper/
  class Connection
    
    REPORT_PERIODS = ["Monthly Free", "Weekly", "Daily"]

    BASE_URL = 'https://itts.apple.com' # :nodoc:
    REFERER_URL = 'https://itts.apple.com/cgi-bin/WebObjects/Piano.woa' # :nodoc:

    # Create a new instance with the username and password used to sign
    # in to the iTunes Connect website
    def initialize(username, password, verbose=false, debug=false)
      @username, @password = username, password
      @verbose = verbose
      @debug = debug
    end

    def verbose?                # :nodoc:
      !!@verbose
    end

    def debug?                  # :nodoc:
      !!@debug
    end

    # Retrieve a report from iTunes Connect. This method will return the
    # raw report file as a String. If specified, the <tt>date</tt>
    # parameter should be a <tt>Date</tt> instance, and the
    # <tt>period</tt> parameter must be one of the values identified
    # in the <tt>REPORT_PERIODS</tt> array, or this method will raise
    # and <tt>ArgumentError</tt>.
    #
    # Any dates given that equal the current date or newer will cause
    # this method to raise an <tt>ArgumentError</tt>.
    # 
    def get_report(date, out, period='Daily')
      date = Date.parse(date) if String === date
      if date >= Date.today
        raise ArgumentError, "You must specify a date before today"
      end

      period = 'Monthly Free' if period == 'Monthly'
      unless REPORT_PERIODS.member?(period)
        raise ArgumentError, "'period' must be one of #{REPORT_PERIODS.join(', ')}"
      end

      # grab the home page
      doc = Nokogiri::HTML(get_content(REFERER_URL))
      login_path = (doc/"form/@action").to_s

      # login
      doc = Nokogiri::HTML(get_content(login_path, {
                                         'theAccountName' => @username,
                                         'theAccountPW' => @password,
                                         '1.Continue.x' => '36',
                                         '1.Continue.y' => '17',
                                         'theAuxValue' => ''
                                       }))

      report_url = (doc / "//*[@name='frmVendorPage']/@action").to_s
      report_type_name = (doc / "//*[@id='selReportType']/@name").to_s
      date_type_name = (doc / "//*[@id='selDateType']/@name").to_s

      # handle first report form
      doc = Nokogiri::HTML(get_content(report_url, {
                                         report_type_name => 'Summary',
                                         date_type_name => period,
                                         'hiddenDayOrWeekSelection' => period,
                                         'hiddenSubmitTypeName' => 'ShowDropDown'
                                       }))
      report_url = (doc / "//*[@name='frmVendorPage']/@action").to_s
      report_type_name = (doc / "//*[@id='selReportType']/@name").to_s
      date_type_name = (doc / "//*[@id='selDateType']/@name").to_s
      date_name = (doc / "//*[@id='dayorweekdropdown']/@name").to_s

      # now get the report
      date_str = case period
                 when 'Daily'
                   date.strftime("%m/%d/%Y")
                 when 'Weekly', 'Monthly Free'
                   date = (doc / "//*[@id='dayorweekdropdown']/option").find do |d|
                     d1, d2 = d.text.split(' To ').map { |x| Date.parse(x) }
                     date >= d1 and date <= d2
                   end[:value] rescue nil
                 end

      raise ArgumentError, "No reports are available for that date" unless date_str
                 
      report = get_content(report_url, {
                             report_type_name => 'Summary',
                             date_type_name => period,
                             date_name => date_str,
                             'download' => 'Download',
                             'hiddenDayOrWeekSelection' => date_str,
                             'hiddenSubmitTypeName' => 'Download'
                           })

      begin
        gunzip = Zlib::GzipReader.new(StringIO.new(report))
        out << gunzip.read
      rescue => e
        doc = Nokogiri::HTML(report)
        msg = (doc / "//font[@id='iddownloadmsg']").text.strip
        $stderr.puts "Unable to download the report, reason:"
        $stderr.puts msg.strip
      end
    end

    private 

    def client
      @client ||= client = HTTPClient.new
    end

    def get_content(uri, query=nil, headers={ })
      $stdout.puts "Querying #{uri} with #{query.inspect}" if self.debug?
      if @referer
        headers = {
          'Referer' => @referer,
          'User-Agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_8; en-us) AppleWebKit/531.9 (KHTML, like Gecko) Version/4.0.3 Safari/531.9'
        }.merge(headers)
      end
      url = case uri
            when /^https?:\/\//
              uri
            else
              BASE_URL + uri
            end

      response = client.get(url, query, headers)

      if self.debug?
        md5 = Digest::MD5.new; md5 << url; md5 << Time.now.to_s
        path = File.join(Dir.tmpdir, md5.to_s + ".html")
        out = open(path, "w") do |f|
          f << "Status: #{response.status}\n"
          f << response.header.all.map do |name, value|
            "#{name}: #{value}"
          end.join("\n")
          f << "\n\n"
          f << response.body.dump
        end
        puts "#{url} -> #{path}"
      end
      
      @referer = url
      response.body.dump
    end

  end
end
