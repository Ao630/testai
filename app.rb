require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require './models.rb'
require 'net/http'
require 'json'
require 'uri'
require 'dotenv/load'
ENV['SSL_CERT_FILE'] = '/etc/ssl/certs/ca-bundle.crt'

enable :sessions
set :sessions, expire_after: 86400

helpers do
  def logged_in?
    !!session[:user_id]  # true / false を返す
  end
  def current_user
    User.find(session[:user_id])
  end
end

get '/' do
  
  Word.where(status: "delete", user_id: session[:user_id]).each do |word|
    @word = Word.new(word: word.word, mean: word.mean, user_id: session[:user_id], file: word.file, status: "")
    @word.save!
    word.delete
  end
  
  @words = Word.where(user_id: nil).order(created_at: :asc)
  if logged_in?
    deletestillword = Word.find_by(status: "still")
    if deletestillword == nil
    else
      deletestillword.delete
    end
    @userwords = current_user.words
    @userfiles = @userwords.pluck(:file).uniq
    p @userwords
    p @userfiles
    # wordlist = session[:userword].word.zip(session[:userword].mean) 
  else
  end
  erb :index
end


get '/signup' do
  erb :signup
end

post '/signup' do
  name = params[:name]
  mail = params[:mail]
  password = params[:password]
  p params
  
  
  if User.exists?(mail: mail)
    puts "メールアドレスはすでに使用されています"
    redirect '/signup'
  else
  
  @user = User.new(name: name, mail: mail, password: password)
  
  if @user.save
    # 保存成功時の処理（例: ログイン状態にする、リダイレクトなど）
    session[:user_id] = @user.id
    redirect '/'
  else
    # 保存失敗時の処理（バリデーションエラーなど）
    redirect '/signup'
  end
  
  end

end


get '/login' do
  erb :login
end


post '/login' do
  user = User.find_by(mail: params[:mail])
  if user && user.authenticate(params[:password])
    session[:user_id] = user.id  # セッションにユーザーIDを保存
    session[:name] = user.name  # セッションにユーザーNAMEを保存
    redirect '/'      # ログイン後の画面などにリダイレクト
  elsif user == nil
    redirect '/login'
  else
    redirect '/login'  
  end
end

post '/logout' do
  session.clear
  redirect '/'
end

get '/create' do
  @file = (Word.maximum(:file) || 0) + 1
  @words = Word.where(user_id: nil).order(created_at: :asc)
  erb :create
end

post '/word-setting' do
  
  word = params[:word]
  mean = params[:mean]
  
  # number = 1
  
  # while Word.exists?(number: number)
  #   number = number + 1
  # end
  
  @word = Word.new(word: word, mean: mean, status: "still")
  @word.save!
  redirect '/create'
end

post '/addword-setting' do
  
  word = params[:word]
  mean = params[:mean]
  
  # number = 1
  
  # while Word.exists?(number: number)
  #   number = number + 1
  # end
  
  @word = Word.new(word: word, mean: mean)
  @word.save!
  redirect '/addword'
end


post '/word-delete' do
  id = params[:id]
  deleteword = Word.find_by(id: id)
  deleteword.delete
  redirect '/create'
end


post '/userword-delete' do
  id = params[:id]
  deleteword = Word.find_by(id: id)
  deleteword.delete
  redirect '/'
end

get '/addword-delete' do
  id = params[:id]
  @file = params[:file]
  p params[:file]
  deleteword = Word.find_by(id: id)
  @word = Word.new(user_id: session[:user_id], word: deleteword.word, mean: deleteword.mean, file: @file, status: "delete")
  @word.save!
  deleteword.delete
  
  @filewords = Word.where(
  user_id: session[:user_id],
  file: @file,
  status: ["", "still"]
)
  erb :addword
end



post '/word-ai' do
 
  word = params[:word]
  
  mean = "Aiによる定義"
  # number = 1
  
  # while Word.exists?(number: number)
  #   number = number + 1
  # end
  
  @word = Word.new(word: word, mean: mean, status: "still")
  @word.save!
  redirect '/create'
end

get '/test' do
  erb :test
end

get '/reload_test' do
  erb :reload_test
end

post '/make-test' do
  words = []
  means = []
  Word.where(user_id: nil).each do |word|
    words.push(word.word)
    if word.mean == "Aiによる定義"
      # Gemini AIによる定義づけ
      if ENV['GEMINI_API_KEY']
        begin
          require 'openssl'
          ENV['SSL_CERT_FILE'] = '/etc/ssl/certs/ca-bundle.crt'
      
          uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")
      
          prompt = <<~PROMPT
            与えられた単語に最も適した定義のみを簡潔に返してください。必要な場合のみ複数の意味の定義を述べること（定義する意味が多い場合、最重要なものから３つまでとする）。
            その単語と判断することができるよう簡潔な内容をできるだけ短くなるように述べること。単語が存在しない、意味が汲み取れない場合は”意味がわかりません”とのみ返すこと。
            （特に英単語の場合はその単語を日本語訳を定義として提示すること。）
            単語： #{word.word}
          PROMPT
      
          body = { contents: [ { parts: [ { text: prompt } ] } ] }
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.ca_file = '/etc/ssl/certs/ca-bundle.crt'
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.open_timeout = 5
          http.read_timeout = 15
          req = Net::HTTP::Post.new(uri.request_uri, { "Content-Type" => "application/json" })
          req['x-goog-api-key'] = ENV['GEMINI_API_KEY']   # ← これで 403 を回避
          req.body = body.to_json
          res  = http.request(req)
          data = JSON.parse(res.body)
          p data
          meant = data.dig("candidates", 0, "content", "parts", 0, "text")&.strip
          mean = meant
        rescue => e
          puts "Gemini API error: #{e.message}"
        end
        puts "GEMINI_API_KEY found"
        puts mean
      else
        puts "GEMINI_API_KEY not found"
      end
    else
      mean = word.mean
    end
    
    means.push(mean)
  end
  
  session[:wordlist] = []
  session[:words] = words
  wordlist = words.zip(means) 
  session[:wordlist] = wordlist
  redirect '/test'
end

post '/keep-words' do
  means = []
  words = []   # ← これが抜けている！！！
  if logged_in?
  else
    # 保存するにはログインしてくださいと表示
    redirect '/login'
  end
  
  Word.where(user_id: nil, status: "still").each do |word|
    words.push(word.word)
    if word.mean == "Aiによる定義"
      # Gemini AIによる定義づけ
      if ENV['GEMINI_API_KEY']
        begin
          require 'openssl'
          ENV['SSL_CERT_FILE'] = '/etc/ssl/certs/ca-bundle.crt'
      
          uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")
      
          prompt = <<~PROMPT
            与えられた単語に最も適した定義のみを簡潔に返してください。必要な場合のみ複数の意味の定義を述べること（定義する意味が多い場合、最重要なものから３つまでとする）。
            その単語と判断することができるよう簡潔な内容をできるだけ短くなるように述べること。単語が存在しない、意味が汲み取れない場合は”意味がわかりません”とのみ返すこと。
            （特に英単語の場合はその単語を日本語訳を定義として提示すること。）
            単語： #{word.word}
          PROMPT
      
          body = { contents: [ { parts: [ { text: prompt } ] } ] }
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.ca_file = '/etc/ssl/certs/ca-bundle.crt'
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.open_timeout = 5
          http.read_timeout = 15
          req = Net::HTTP::Post.new(uri.request_uri, { "Content-Type" => "application/json" })
          req['x-goog-api-key'] = ENV['GEMINI_API_KEY']   # ← これで 403 を回避
          req.body = body.to_json
          res  = http.request(req)
          data = JSON.parse(res.body)
          p data
          meant = data.dig("candidates", 0, "content", "parts", 0, "text")&.strip
          mean = meant
        rescue => e
          puts "Gemini API error: #{e.message}"
        end
        puts "GEMINI_API_KEY found"
        puts mean
      else
        puts "GEMINI_API_KEY not found"
      end
    else
      mean = word.mean
    end
    
    means.push(mean)
  end
  
  session[:wordlist] = []
  session[:words] = words
  wordlist = words.zip(means) 
  session[:wordlist] = wordlist
  
  
  file = (Word.maximum(:file) || 0) + 1
  session[:wordlist].each do |word, mean|
    word = word
    mean = mean
    user = session[:user_id]
    
    @word = Word.new(word: word, mean: mean, file: file, user_id: user, status: "")
    #ユーザーと単語を紐付け
    @word.save!
    
  end
  redirect '/'
end

post '/leave_create' do
  garbage = Word.where(user_id: nil)
  garbage.delete_all
  p "user_id=nilを削除"
end

post '/reload-test' do
  words = []
  means = []
  Word.where(user_id: session[:user_id],file: params[:file]).each do |word|
    words.push(word.word)
    mean = word.mean
    means.push(mean)
  end
  session[:wordlist] = []
  session[:words] = words
  wordlist = words.zip(means) 
  session[:wordlist] = wordlist
  redirect '/reload_test'
end

get '/addword' do
  @file = params[:file]
  
  @filewords = Word.where(
  user_id: session[:user_id],
  file: params[:file],
  status: ["", "still"]
)
  p @filewords
  erb :addword
end

post '/addword-setting' do
  
  word = params[:word]
  mean = params[:mean]
  file = params[:file]
  
  @word = Word.new(word: word, mean: mean, file: file, user_id: session[:user_id])
  @word.save!
  redirect '/'
end

post '/addmake-test' do
  @file = params[:file]
  Word.where(user_id: session[:user_id], file: @file, status: "still").each do |word|
    @word = Word.new(word: word.word, mean: word.mean, user_id: session[:user_id], file: @file, status: "")
    @word.save!
    puts word
    p "これ"
    word.delete
  end
  
  Word.where(user_id: session[:user_id], file: @file, status: "delete").each do |word|
    word.delete
  end
  redirect'/'
end

post '/plusaddword' do
  word = params[:word]
  mean = params[:mean]
  session[:file] = params[:file]
  @word = Word.new(word: word, mean: mean, user_id: session[:user_id], file: session[:file], status: "still")
  @word.save!
  session[:filewords] = Word.where(user_id: session[:user_id], file: params[:file])
  redirect '/plusaddword'
end

get '/plusaddword' do
  @filewords = session[:filewords]
  @file = session[:file]
  erb :addword
end

get '/addword-ai' do
  word = params[:word]
  @file = params[:file]
  mean = "Aiによる定義"
  # number = 1
  
  # while Word.exists?(number: number)
  #   number = number + 1
  # end
  
  @word = Word.new(user_id: session[:user_id], word: word, mean: mean, file: @file)
  @word.save!
  @filewords = Word.where(user_id: session[:user_id], file: params[:file])
  erb :addword
end

get '/writing-test' do
  @file = params[:file]
  @filewords = Word.where(user_id: session[:user_id], file: params[:file], status: "")
  erb :writing_test
end

get '/:file/details' do
  @file = params[:file]
  @words = Word.where(user_id: session[:user_id], file: params[:file], status: "")
  erb :details
end