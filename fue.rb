require 'sinatra'
require 'uglifier'
require 'sqlite3'
require './app/routes'
require 'sanitize'
require 'json'

# server configuration
set :server, :thin
enable :sessions
configure :development do
    enable :logging
end

# bootstrap
IO.write('./views/default_layout.rhtml', IO.read('./views/default_layout.pre.rhtml').gsub('/**NEED-FUE-MIN-JS**/', Uglifier.compile(IO.read('./views/javascript/fue.js'))))
unless File.exists? './db/fue.sqlite3'
    puts 'Install DB first (rake install).'
    exit
end
db = SQLite3::Database.new './db/fue.sqlite3'


before do
    # auth
    begin
        if session['uid'] < 1
            session['uid'] = 1
        end
    rescue
        session['uid'] = 1
    end
    db.execute('SELECT name FROM users WHERE user_id=?', session['uid']) do |row|
        if session['uid'] == 1
            session['uname'] = row[0]
        else
            unless session['uname'] == row[0]
                session['uid'] = 1
                session['uname'] = db.get_first_value('SELECT name FROM users WHERE user_id=1')
            end
        end
    end
end


get Routes::Index do
    erb :index, :layout => :default_layout
end

post Routes::Login do
    if params['fue-username'].nil?
        redirect to(Routes::Login)
    end
    username = Sanitize.fragment(params['fue-username']).strip
    if username.length == 0
        redirect to(Routes::Login)
    else
        row = db.execute('SELECT user_id FROM users WHERE name=?', username)
        logger.info row
        if !row.nil? && row.length > 0
            session['uid'] = row[0][0]
            session['uname'] = username
            redirect to(session['login_from'])
        else
            db.execute('INSERT INTO users(name) VALUES (?)', username)
            session['uid'] = db.get_first_value('SELECT user_id FROM users WHERE name=?', username)
            session['uname'] = username
            redirect to(session['login_from'])
        end                
    end    
end

get Routes::Login do
    if params['from'] == 'login_btn'
        session['login_from'] = request.referrer
    end
    if session['uid'] > 1
        redirect to(Routes::Index)
    else
        erb :login, :layout => :default_layout        
    end
end

get Routes::Logout do 
    session['uid'] = 0
    redirect back
end


get Routes::New do
    if session['uid'] <= 1 && params['continue'] != 'true'
        session['login_from'] = url(Routes::New) + '?continue=true'
        redirect to(Routes::Login)
    else
        erb :new, :layout => :default_layout, :locals => {:expr => nil}
    end
end

post Routes::New do
    eid = params['expr_id'].to_i
    phr = Sanitize.fragment(params['phrase']).strip
    con = Sanitize.fragment(params['context']).strip
    des = Sanitize.fragment(params['description']).strip
    
    result = {
        'result' => 'fail',
        'message' => ''
    }

if phr.length == 0
    result['message'] = '短语不能为空'
    halt result.to_json
end
if con.length == 0
    result['message'] = '例句不能为空'
    halt result.to_json
end
if des.length == 0
    result['message'] = '注解不能为空'
    halt result.to_json
end
if con.include? phr
    con.gsub!(phr, "<mark><b>#{phr}</b></mark>")
else
    result['message'] = '例句中需要包含短语。'
    halt result.to_json        
end
if db.get_first_value('SELECT COUNT(*) FROM expr_body WHERE phrase=? AND context=? AND rowid <> ?', [phr, con, eid]) > 0
    result['message'] = '和现有的词条重复。'
    halt result.to_json
end
if eid == 0
    # new
    t = Time.now
    db.execute('INSERT INTO expr_info(update_at, user_id, version) VALUES (?,?,?)', [t.to_i, session['uid'], 1])
    eid = db.get_first_value('SELECT expr_id FROM expr_info WHERE update_at=? AND user_id=? AND version=?', [t.to_i, session['uid'], 1])
    if eid > 0
        db.execute('INSERT INTO expr_body(rowid, context, phrase, description) VALUES (?,?,?,?)',[eid, con, phr, des])
        db.execute('INSERT INTO contributes(expr_id, user_id) VALUES (?,?)', [eid, session['uid']])
        result['result'] = 'ok'
        result['goto'] = Routes.url_for({'entry'=>'detail', 'expr_id'=>eid})
        result.to_json
    else
        halt 500
    end
else
    if db.get_first_value('SELECT COUNT(*) FROM expr_info WHERE expr_id=?', eid) == 0
        halt 400
    else
        body_row = db.get_first_row('SELECT context, phrase, description FROM expr_body WHERE rowid=?', eid)
        info_row = db.get_first_row('SELECT update_at, user_id, version FROM expr_info WHERE expr_id=?', eid)
        db.execute('INSERT INTO history(expr_id, context, phrase, description, update_at, user_id, version) VALUES (?,?,?,?,?,?,?)', [eid, body_row[0], body_row[1], body_row[2], info_row[0], info_row[1], info_row[2]])
        db.execute('UPDATE expr_body SET context=?, phrase=?, description=? WHERE rowid=?', [con, phr, des, eid])
        db.execute('UPDATE expr_info SET update_at=?, user_id=?, version=? WHERE expr_id=?', [Time.now.to_i, session['uid'], info_row[2]+1, eid])
        if db.get_first_value('SELECT COUNT(*) FROM contributes WHERE expr_id=? AND user_id=?', [eid, session['uid']]) == 0
            db.execute('INSERT INTO contributes(expr_id, user_id) VALUES (?,?)', [eid, session['uid']])
        end
        result['result'] = 'ok'
        result['goto'] = Routes.url_for({'entry'=>'detail', 'expr_id'=>eid})
        result.to_json
    end
end
end

get Routes::Detail do |expr_id|
    eid = expr_id.to_i
    row = db.get_first_row('SELECT context, phrase, description FROM expr_body WHERE rowid=?', eid)
    if row.length == 0
        redirect to(Routes::Index)
    else
        contr = db.execute('SELECT users.name FROM contributes JOIN users ON users.user_id = contributes.user_id WHERE contributes.expr_id=?', eid).flatten.join(',')
        erb :detail, :layout => :default_layout, :locals => {
            :expr_phrase => row[1],
            :expr_context => row[0],
            :expr_description => row[2],
            :expr_contribute => contr,
            :expr_id => eid,
            :expr_more => {
                'history' => false,
                'version' => 0
            }
        }
    end
end

get Routes::HisEntry do |expr_id, version|
    eid = expr_id.to_i
    ver = version.to_i
    row = db.get_first_row('SELECT history.context, history.phrase, history.description, history.update_at, users.name FROM history JOIN users ON users.user_id = history.user_id WHERE expr_id=? AND version=?', [eid, ver])
    if row.length == 0
        redirect to(Routes::Index)
    else
        erb :detail, :layout => :default_layout, :locals => {
            :expr_phrase => row[1],
            :expr_context => row[0],
            :expr_description => row[2],
            :expr_contribute => row[4],
            :expr_id => eid,
            :expr_more => {
                'history' => true,
                'update_at' => Time.at(row[3]).strftime("%F %R"),
                'version' => ver
            }
        }
    end
end

get Routes::Card do 
    row = db.get_first_row('SELECT rowid, context, phrase, description FROM expr_body ORDER BY RANDOM() LIMIT 1') 
    erb :card, :locals => {
        :expr_phrase => row[2],
        :expr_context => row[1],
        :expr_description => row[3],
        :expr_id => row[0]
    }
end

get Routes::Update do |expr_id|
    if session['uid'] <= 1 && params['continue'] != 'true'
        session['login_from'] = request.path + '?continue=true'
        redirect to(Routes::Login)
    else
        eid = expr_id.to_i
        row = db.get_first_row('SELECT context, phrase, description FROM expr_body WHERE rowid=?', eid)
        if row.length == 0
            redirect to(Routes::Index)
        else
            erb :new, :layout => :default_layout, :locals => {
                :expr => {
                    'phrase' => row[1],
                    'context' => Sanitize.fragment(row[0]),
                    'description' => row[2],
                    'rowid' => eid
                }
            }
        end
    end
end

get Routes::Search do
    if params['search'].nil?
        erb :search, :locals => {:f_search => ''}, :layout => :default_layout do
            erb :sresult, :locals => { :rows => [] }
        end
    else
        s = Sanitize.fragment(params['search']).strip
        if s.length == 0
            erb :search, :locals => {:f_search => ''}, :layout => :default_layout do
                erb :sresult, :locals => { :rows => [] }
            end
        else            
            if s.ascii_only?
                rows = db.execute('SELECT rowid, context, phrase, description FROM expr_body WHERE expr_body MATCH ? ORDER BY bm25(expr_body)', s)
            else
                rows = db.execute('SELECT rowid, context, phrase, description FROM expr_body WHERE description LIKE ?', "%#{s}%")
            end
            erb :search, :locals => {:f_search => s}, :layout => :default_layout do
                erb :sresult, :locals => { :rows => rows }
            end
        end
    end
end

get Routes::History do |expr_id|
    eid = expr_id.to_i
    rows = db.execute('SELECT history.update_at, history.version, users.name FROM history JOIN users ON users.user_id = history.user_id WHERE history.expr_id=? ORDER BY history.update_at DESC', eid)
    expr_phrase = db.get_first_value('SELECT phrase FROM expr_body WHERE rowid=?', eid)
    erb :history, :layout => :default_layout, :locals => { :expr_phrase => expr_phrase, :rows => rows, :expr_id => eid }
end

get Routes::Comment do |expr_id, version|
    eid = expr_id.to_i
    if db.get_first_value('SELECT COUNT(*) FROM expr_info WHERE expr_id=?', eid) == 0
        halt 400
    end
    ver = version.to_i
    current_ver = db.get_first_value('SELECT version FROM expr_info WHERE expr_id=?', eid)    
    if ver == 0 || ver > current_ver
        ver = current_ver
    end
    rows = db.execute('SELECT comments.content, comments.create_at, users.name FROM comments JOIN users ON users.user_id = comments.user_id WHERE comments.expr_id=? AND version=? ORDER BY comments.create_at DESC', [eid, ver])
    erb :comment, :locals => { :rows => rows }
end

post Routes::Comment do |expr_id, version|
    eid = expr_id.to_i
    if db.get_first_value('SELECT COUNT(*) FROM expr_info WHERE expr_id=?', eid) == 0
        halt '找不到表达'
    end
    comment = Sanitize.fragment(params['content']).strip
    if comment.length == 0
        halt '内容为空'
    end
    current_ver = db.get_first_value('SELECT version FROM expr_info WHERE expr_id=?', eid)
    db.execute('INSERT INTO comments(user_id, expr_id, version, create_at, content) VALUES (?,?,?,?,?)', [session['uid'], eid, current_ver, Time.now.to_i, comment])
    'OK'
end