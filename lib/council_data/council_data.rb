class CouncilData
  
  def self.import
    json = JSON.parse open("http://openlylocal.com/councils/open.json").read

    json["councils"].each do |council|
      c = Council.find_or_create_by_name(council["name"])
  
      c.os_id = council["os_id"]
      c.authority_type = council["authority_type"]
      council["region"] = council["country"] if council["region"].nil? # Wales, NI and Scotland don't have 'regions' per se
      c.region = council["region"]
      c.url = council["url"].chomp("/")
      c.open_data_url = council["open_data_url"]
  
      c.save
    end
  end
  
  def self.discover
    count = 0
    suffixes = ["data", "open-data", "opendata", "transparency"]
    
    councils = Council.where(:open_data_url => nil).all
    
    councils.each do |council|
      
      url = council.url + "/fdsfdsfsdf" # Junk URL to test this council returns correct HTTP headers
      io = open(url) rescue nil
      
      if io != nil && io.status[0] == "200"
        # By rights, this should be a 404
        council.discovered = false
        puts "LIES!"
      else      
        suffixes.each do |suffix|
          url = council.url + "/" + suffix
          io = open(url) rescue nil
        
          if io != nil && io.status[0] == "200"
            council.open_data_url = url
            council.discovered = true
            council.save
            count =+ 1
            puts url + ": Yup"
            break
          end
        
          council.discovered = false
        end
      end
    end
    
    puts "#{count} extra councils found"
  end
  
  def self.homepage
    councils = Council.where(:open_data_url.ne => nil, :clicks => nil).all
    
    councils.each do |council|
      firstlinks = CouncilData.find_links(council.url, council.url, council.open_data_url)
      
      if firstlinks.class == String
        council.clicks = 1
        puts "#{council.name}: Found in 1"
        council.save
      end
    end
  end
  
  def self.two_clicks
    councils = Council.where(:open_data_url.ne => nil, :clicks => nil).all
    
    councils.each do |council|
      links = CouncilData.find_links(council.url, council.url, council.open_data_url)
      
      links.each do |link|
        two_links = CouncilData.find_links(link[:href], council.url, council.open_data_url)
        
        if two_links.class == String
          council.clicks = 2
          council.link_found = two_links
          puts "#{council.name}: Found in 2"
          council.save
          break
        end
      end
    end
  end
  
  def self.three_clicks
    councils = Council.where(:open_data_url.ne => nil, :clicks => nil).all
    
    councils.each do |council|
      puts council.name
      links = CouncilData.find_links(council.url, council.url, council.open_data_url)
      
      unless links.nil?
        links.each do |link|
          two_links = CouncilData.find_links(link, council.url, council.open_data_url)
        
          unless two_links.nil?
            two_links.each do |link|
              three_links = CouncilData.find_links(link, council.url, council.open_data_url)
          
              if three_links.class == String
                council.clicks = 3
                council.link_found = three_links
                puts "#{council.name}: Found in 3"
                council.save
                break
              end          
            end
          end
        end
      end
      
      council.clicks = 0
      council.save
    end
  end
  
  def self.find_links(url, root_url, od_url)    
    unless url.include?(root_url)
      url = root_url + url
    end
    
    agent = Mechanize.new
    
    page = agent.get(url) rescue nil
    
    unless page.nil? || page.class != Mechanize::Page      
      links = page.search("a[href^='#{root_url}'], a[href^='/']").map{|link| link[:href]}.uniq!
      
      unless links.nil?               
        links.each do |link|
          if link == od_url || link =~ /#{od_url.gsub(root_url, "")}$/
            return url
            break
          end
        end
      end
      
      return links
    
    else
      return []
    end
  end
  
  def self.export 
    CSV.open("councils.csv", "w") do |csv|
      csv << ["name", "region", "type", "homepage", "data_url", "clicks", "link_found"]
      
      Council.all.each do |council|
        csv << [council.name, council.region, council.authority_type, council.url, council.open_data_url, council.clicks, council.link_found]
      end
    end
  end
  
end