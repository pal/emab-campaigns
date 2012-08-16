require 'sinatra'
require 'haml'

require 'nokogiri'
require 'open-uri'
require 'uri'
require 'net/http'

if (!development?)
  DATA_DIR = '/home/emab/emab-img/'
else
  DATA_DIR = '/tmp/emab-img/'
end

get '/play' do
  send_file File.join(settings.public_folder, 'play/index.html')
end

get '/play2' do
  File.read(settings.public_folder, 'play/index.html')
end

get '/play3' do
  redirect '/play/index.html'
end

get '/current_folder.json' do
  content_type :json
  send_file File.join(settings.public_folder, 'current_folder.json')
#  { :key1 => 'value1', :key2 => 'value2' }.to_json
end

get '/' do
  @campaigns = get_week_data_results
  @current_week = get_current_week
  @current_campaign_item = (@campaigns.select{ |a| a['is_active_campaign'] == true }).first
  @current_campaign_item = {} unless @current_campaign_item
  haml :index
end

get '/foo/:bar' do
  "You asked for foo/#{params[:bar]}"
end

def get_zip(url, filename)
  File.open(filename,'w'){ |f|
  uri = URI.parse(url)
    Net::HTTP.start(uri.host,uri.port){ |http| 
      http.request_get(uri.path){ |res| 
        res.read_body{ |seg|
          f << seg
          #hack -- adjust to suit:
          sleep 0.005 
        }
      }
    }
  }
end

def d(str)
  puts str
end

def has_zip(url)
  url = URI.parse(url)
  rv = false

  Net::HTTP.start(url.host, url.port) do |http|
    response = http.head(url.path)
    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      case response.content_type
      when "application/zip", "application/octet-stream"
        rv = true
      else
        d "HTTP ERROR: bad response code: #{response.content_type} for #{url}"
      end
    else
      #d "file not found: #{url}"
    end
  end
  return rv
end

def get_current_week
  # %U - Week number of the year, starting with the first Sunday as the first day of the first week (00..53)
  # %V - Week number of year according to ISO 8601 (01..53)
  # %W - Week number of the year, starting with the first Monday as the first day of the first week (00..53)
  Time.now.strftime("%V").to_i
end

def get_week_data_results
  # typical campaign content: 
  # <a href="?folderId=209">Kampanj v 13-16 Påsk 2012</a>
  # <a href="?folderId=207">Kampanj v 9-12 2012</a>

  # link format:
  # {'url'=>'', 'url'=>'', 'url'=>'', }

  # helped by http://rubular.com/
  regex = /kampanj\s?v\s?(?<w1>\d{1,2})-(?<w2>\d{1,2})\s(?:.)*(?<year>\d{4})+?/i # only 1.9
  regex = /kampanj\s?v\s?(\d{1,2})-(\d{1,2})\s(?:.)*(\d{4})+?/i # for 1.8
  root_url = 'http://www.emab.org/Bazment/Intranet/sv/'
  
  doc = Nokogiri::HTML(open(root_url + 'Kampanjer.aspx'))
  links = Array.new
  
  week_items = []
  week_number = get_current_week
  d "Current week is #{week_number}"
  
  doc.css('table.doc-list td.name a').each do |link|
    item = {}
    
    if link.content =~ regex
      m = regex.match(link.content)
      w1 = m[1].to_i # 1.9: m[:w1]
      w2 = m[2].to_i
      year = m[3].to_i
      
      week = "#{w1}-#{w2}"

      zipurl = "http://store.printley.se/pickup/printley/EMAB_v#{week}.zip"
      zip_dir = "#{DATA_DIR}_zipdir"
      local_zip = "#{zip_dir}/EMAB_#{week}.zip"
      unzip_dir = "#{DATA_DIR}_img_input/#{year}/#{week}"
      unzipped_img_dir = "#{unzip_dir}/EMAB_#{week}"
      img_output_base_dir = "#{DATA_DIR}_img_output"
      img_output_dir = "#{img_output_base_dir}/#{year}/#{week}"
      
      item['week_start'] = w1
      item['week_end'] = w2
      item['year'] = year
      item['zipurl'] = zipurl
      item['is_active_campaign'] = false
      item['has_images'] = false
      
      d("Testing #{year} - #{week}")
      if (has_zip(zipurl))
        d("#{week} has remote zip")
        if (!File.exists?(local_zip))
          `mkdir -p #{zip_dir}`
          d("#{week} has no local zip")
          get_zip(zipurl, local_zip)
          `mkdir -p #{unzip_dir}`
          `unzip -o #{local_zip} -d #{unzip_dir}`
          d "Unzipped remote file #{local_zip} to #{unzip_dir}"
          
          # rename files
          count = 1
#          Dir.glob(unzipped_img_dir + "/*").sort.each do |f|
					Dir["#{unzip_dir}/*/*"].reject{ |f| f["#{unzip_dir}/*/__MACOSX/*"] }.sort.each do |f|
            d f
            File.rename(f, File.dirname(f) + "/IMG_" + ("%04d" % count) + File.extname(f))
            count += 1
          end
          
          # convert file to suit screen display (requires imagemagick)
          `mkdir -p #{img_output_dir}`
          # out TVs have a resolution of 1366x768, change to this?
          `mogrify -format jpg -path #{img_output_dir} -quality 60 -size 1920x1080 #{unzip_dir}/*/IMG_*`
        end
        
        if (File.exists?(img_output_dir))
          item['has_images'] = true
          item['image_count'] = Dir["#{img_output_dir}/*.jpg"].length
          item['image_path'] = img_output_dir
        end
      end
      
      if ((w1..w2).include?(week_number))
        item['is_active_campaign'] = true
        
        aFile = File.new(File.join(settings.public_folder, 'current_folder.json'), "w")
        aFile.write("{current_folder:\"#{year}/#{week}\",image_count:#{item['image_count']}}\n")
        aFile.close
      end
      
      week_items << item
    end
  end
  week_items
end

require 'sinatra/base'

module Sinatra
  module HTMLEscapeHelper
    def h(text)
      Rack::Utils.escape_html(text)
    end
  end

  helpers HTMLEscapeHelper
end


__END__

@@ layout
%html
  %head
    %title EMAB Kampanjer
    %meta{"http-equiv" => "Content-Type", :content => "text/html; charset=utf-8"}
    %link{"rel" => "stylesheet", "href" => "/res/emab.css", "type" => "text/css"}
  %body
    = yield

@@ index
%h1 EMAB kampanjhantering
%p="Nuvarande kampanj är #{h @current_campaign_item['week_start']}-#{h @current_campaign_item['week_end']}"

%table
  %thead
    %tr
      %th Veckor
      %th Finns bilder?
      %th Länk
      %th Antal bilder
      %th Nuvarande?
  %tbody
    - @campaigns.each do |campaign|
      %tr
        %td="#{campaign['week_start']}-#{campaign['week_end']}"
        %td{:class => "#{campaign['has_images']}"}
        %td
          %a{:href => campaign['image_path']}="#{campaign['week_start']}-#{campaign['week_end']}" 
        %td="#{campaign['image_count']}"
        %td{:class => "#{campaign['is_active_campaign']}"}
