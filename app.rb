require 'rubygems'
require 'sinatra'
require 'sinatra/activerecord'
require 'rack-flash'
require 'net/http'
require 'nokogiri'

set :database, 'sqlite:///development.db'

class GenericData < ActiveRecord::Base
end

enable :sessions
use Rack::Flash

before do
  @brackets = JSON.parse(GenericData.find_by_name('brackets').content)

  if ['/'].any?{|p| p == request.env['REQUEST_URI'] }
    sync = GenericData.where(:name => 'pgatour_cache').first

    GenericData.where(:name => 'pgatour_cache').destroy_all if params[:update] || (sync && sync.created_at < 5.minutes.ago)
    @results = if GenericData.where(:name => 'pgatour_cache').first
      @last_updated = sync.created_at
      JSON.parse(sync.content)
    else
      domain = 'http://www.majorschampionships.com'
      path = '/usopen/2012/scoring/'
      url = URI.parse domain
      req = Net::HTTP::Get.new path
      http = Net::HTTP.new(url.host, url.port)
      http.read_timeout = 30

      body = http.start do |http|
        http.request(req).body
      end

      doc = Nokogiri::HTML(body)

      @results = {
        'tournament' => 'U.S. Open',
        'players' => {},
        'low_rounds_of_day' => {}
      }
      doc.css('.leaderMain tbody')[2].css('tr').each do |tr|
        tds = tr.css('td')

        if tds.size == 11
          place = tds[0].content.strip
          place = place.gsub('-', '')
          finished = place.to_s.match(/^T?[0-9]+$/)
          raw_place = finished ? place.to_s.gsub('T', '').to_i : nil

          rounds = {
            1 => tds[6].content.strip,
            2 => tds[7].content.strip,
            3 => tds[8].content.strip,
            4 => tds[9].content.strip
          }

          value = case raw_place
            when 1
              10
            when 2..5
              6
            when 6..10
              4
            when 11..25
              2
            when 26..1000
              1
            else
              0
          end
          @results['players'][tds[2].content.strip] = {
            'name' => tds[2].content.strip,
            'place' => place,
            'rounds' => rounds,
            'value' => value,
            'finished' => finished
          }
        end
      end
      @results['total_players'] = @results['players'].keys.size
      @results['players_making_cut'] = @results['players'].values.select{|p| p['place'].to_s.match(/^T?[0-9]+$/)}.size
      (1..4).each do |round_number|
        round_hash = @results['players'].select{|n,p| p['rounds'][round_number].to_s.match(/^[0-9]+$/)}.values.group_by{|p| p['rounds'][round_number]}
        @results['low_rounds_of_day'][round_number] = round_hash[round_hash.keys.sort.first] ? round_hash[round_hash.keys.sort.first].map{|p| p['name']} : []
      end
      @results['players'].values.each{|p| p['value'] += p['rounds'].keys.select{|k| @results['low_rounds_of_day'][k].include?(p['name'])}.size }

      GenericData.create!(:name => 'pgatour_cache', :content => @results.to_json)

      redirect '/'
    end
  end
end

def get_or_post(path, opts={}, &block)
  get(path, opts, &block)
  post(path, opts, &block)
end

get_or_post '/' do
  @modified_brackets = Marshal.load(Marshal.dump(@brackets))

  @modified_brackets.each do |bracket|
    bracket['total'] = 0
    bracket['picks'].each do |pick|
      player = @results['players'][pick['name']]

      if player
        pick['place'] = player['place']
        pick['value'] = player['value']
        bracket['total'] += player['value']
      else
        pick['value'] = 0
        pick['place'] = 'Not Found'
      end
    end
    bracket['total'] += 5 if bracket['picks'].all?{|p| @results['players'][p['name']] && @results['players'][p['name']]['finished'] }
  end

  @modified_brackets = @modified_brackets.sort_by{|v| v['total'] }.reverse

  erb :index
end

post '/update' do
  if params[:passphrase] == 'secret'
    gd = GenericData.find_or_create_by_name('brackets')
    gd.update_attributes!(:content => params[:brackets])
  end
  redirect '/'
end









