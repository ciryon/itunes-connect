require "ostruct"

# This class transforms the raw input given in the constructor into a
# series of objects representing each row. You can either get the
# entire set of data by accessing the +data+ attribute, or by calling
# the +each+ method and handing it a block.
class ItunesConnect::Report
  include Enumerable

  # The report as a Hash, where the keys are country codes and the
  # values are Hashes with the keys, <tt>:date</tt>, <tt>:upgrade</tt>,
  # <tt>:install</tt>.
  attr_reader :data

  # Give me an +IO+-like object (one that responds to the +each+
  # method) and I'll parse that sucker for you.
  def initialize(input)
    
    @data = Hash.new { |h,k| h[k] = { }}
    input.each do |line|
      line.chomp!
      next if line =~ /^(Provider|$)/
      if line =~ /DOCTYPE/ # bail if we get unparseable
        return
      end
      tokens = line.split(/\t/)
      i = 0
      tokens.each do |token|
        puts "token #{i}: "+token
        i = i+1
      end
      country = tokens[12]
      count = tokens[7].to_i
      @data[country][:app_name] = tokens[4]
      @data[country][:date] = Date.parse(tokens[9])
      type = tokens[6]
      if type.match(/^7/)
        @data[country][:upgrade] = count
      end
      if type.match(/^1/)
        @data[country][:install] = count
      end
    end
  end

  # Yields each parsed data row to the given block. Each item yielded
  # has the following attributes:
  #   * country
  #   * date
  #   * install_count
  #   * upgrade_count
  def each                      # :yields: record
    @data.each do |country, value|
      if block_given?
        yield OpenStruct.new(:country => country,
                             :date => value[:date],
                             :install_count => value[:install] || 0,
                             :upgrade_count => value[:upgrade] || 0,
                             :app_name => value[:app_name])
      end
    end
  end

  # The total number of rows in the report
  def size
    @data.size
  end
end
