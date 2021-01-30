#!/usr/bin/env ruby
#
#  cb-cost.rb
#
#  Created by Joshua Hamor on 2017-05-10.
#  Copyright 2017 Hectomertz, Inc. All rights reserved.
#

require 'coinbase/wallet'
require 'csv'
require 'optparse'
require 'yaml'

#
# OptionParser
#
CONFIG = {
  :currency           => ["BTC","ETH","LTC"],
  :debug              => nil,
  :filename           => nil,
}

ARGV << '-h' if ARGV.empty?

opts = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [[-h] | [-D] [-f <report>]]"

  opts.on("-D", "--debug", "Enable debug mode") do
    CONFIG[:debug] = true
  end
  opts.on("-f", "--file [arg]", "Set report file") do |arg|
    CONFIG[:filename] = arg.split(",")
  end
  opts.on("-h", "--help", "Display help information") do
  end
end

begin
  opts.parse!
  if CONFIG[:filename].nil?
    puts opts
    exit 1
  end
rescue OptionParser::InvalidOption => e
  puts e
  puts opts
  exit 1
end

#
# Classes
#
class CB
  def self.load_secrets()
    secrets = YAML.load_file("./secrets.yml")["production"]
  end
  def self.process_csv(file)
    coins    = 0
    currency = nil
    spent    = 0

    puts "DEBUG: looping over CSV file(s)" if CONFIG[:debug]
    puts "DEBUG: file: #{file}" if CONFIG[:debug]
    CSV.foreach(file) do |row|
      if CONFIG[:currency].include?(row[2])
        currency      = row[2]
        coin_amount   = row[3].to_f
        dollar_amount = row[6].to_f
        fee           = row[7].to_f

        case row[1]
        when "Buy"
          coins = coins + coin_amount
          spent = spent + dollar_amount
        when "Send"
          coins = coins - coin_amount
          spent = spent - dollar_amount
        end
        puts "DEBUG: --> coins: #{coins} spent: #{spent}" if CONFIG[:debug]
      end
    end
    puts "DEBUG: --> coins: #{coins} currency: #{currency} spent: #{spent}" if CONFIG[:debug]
    return { :coins => coins, :currency => currency, :spent => spent, }
  end
  def self.acquire_price(currency, api_key, api_secret)
    client = Coinbase::Wallet::Client.new(api_key: api_key, api_secret: api_secret)
    price = client.buy_price({currency_pair: "#{currency}-USD"})
    return price["amount"]
  end
end

#
# Main
#
grand_delta   = 0
grand_percent = 0
grand_total   = 0
grand_worth   = 0

CONFIG[:filename].each do |file|
  secrets = CB.load_secrets()
  data = CB.process_csv(file)
  current_rate = CB.acquire_price(data[:currency], secrets["api_key"], secrets["api_secret"])

  total = "%.2f" % (data[:spent].to_f)
  worth = "%.2f" % (data[:coins] * current_rate.to_f)

  grand_total = "%.2f" % (grand_total.to_f + total.to_f)
  grand_worth = "%.2f" % (grand_worth.to_f + worth.to_f)

  delta   = "%.2f" % (worth.to_f - total.to_f)
  percent = "%.2f" % (delta.to_f / total.to_f * 100)

  puts "#{data[:currency]} total (spent/worth/delta/percent): $#{total} / $#{worth} / $#{delta} / #{percent}%"
end

grand_delta   = "%.2f" % (grand_worth.to_f - grand_total.to_f)
grand_percent = "%.2f" % (grand_delta.to_f / grand_total.to_f * 100)

puts "Total - Spent: $#{grand_total} / Worth: $#{grand_worth} / Gain: $#{grand_delta} / Percent: #{grand_percent}"
