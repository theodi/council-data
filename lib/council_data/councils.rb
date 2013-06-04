class Council
  include MongoMapper::Document

  key :os_id, Integer
  key :name, String
  key :url, String
  key :open_data_url, String
  key :clicks, Integer
  key :discovered, Boolean
  key :link_found, String
  
  timestamps!
end