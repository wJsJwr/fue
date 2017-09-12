require 'sqlite3'
dbpath = File.expand_path('./fue.sqlite3', __dir__)
if File.exists? dbpath
    exit
end
# system("touch #{dbpath}")
SQLite3::Database.new dbpath do |db|
    db.execute_batch(IO.read(File.expand_path('./schema.sql', __dir__)))
end
