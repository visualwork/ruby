require 'sinatra'
require 'rest_client'
require 'data_mapper'
enable :sessions
require 'date'

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/hotel.db")

class User
  include DataMapper::Resource
  property :id, Serial
  property :user_email, String
  property :user_password, String
  property :created_at, DateTime
  property :admin, Boolean
  validates_uniqueness_of :user_email
end

class Hotel
  include DataMapper::Resource 
  property :id, Serial
  property :title, String
  property :description, String, :length => 100
  property :image_src, String, :length => 100
  property :start_at, Date
  property :end_at, Date
  property :size, Integer
  has n, :tickets
end

class Ticket
  include DataMapper::Resource 
  property :id, Serial
  property :user_id, Integer
  property :hotel_id, Integer
  property :reservation_date, Date
end


DataMapper.finalize
User.auto_upgrade!
Hotel.auto_upgrade!
Ticket.auto_upgrade!


get '/' do
  @hotels = Hotel.all
  @c_set = ["서울", "뉴욕", "파리", "판교", "케이프타운"]
  @email_name = session[:email]
  erb :index
end

get '/login' do
  @c_set = ["서울", "뉴욕", "파리", "판교", "케이프타운"]
    erb :login
end

post '/login_process' do
  @comment = ""

  database_user = User.first(:user_email => params[:user_email])
  md5_user_password = Digest::MD5.hexdigest(params[:user_password])

  if !database_user.nil?
   if database_user.user_password == md5_user_password
   session[:email] = params[:user_email]
     if database_user.admin == true 
     redirect '/admin'
     else
       redirect '/'
      end
   else
       "비밀번호가 틀렸습니다."
   end
  else
    "해당 유저가 없습니다."
 end
end


get '/logout' do 
  session.clear
  redirect '/'
end

get '/join' do
   @c_set = ["서울", "뉴욕", "파리", "판교", "케이프타운"]
   erb :join
end

post '/join_process' do
   n_user = User.new
   n_user.user_email = params[:user_email]
   md5_password = Digest::MD5.hexdigest(params[:user_password])
   n_user.user_password = md5_password
   n_user.admin = false

   n_user.save	
   redirect '/'
end


['/admin', "/user_delete/*"].each do |path|
before path do
   user = User.first(:user_email => session[:email])
   if (user.nil?) or (user.admin != true)
   redirect '/'
  	end
   end
end

get '/admin' do
    @users = User.all
    @hotels = Hotel.all
    erb :admin
end



get '/user_delete/:user_id' do
   user = User.first(:id => params[:user_id])
   user.destroy
   redirect '/admin'
end

get '/detail/:id' do
  @c_set = ["서울", "뉴욕", "파리", "판교", "케이프타운"]
  @hotel = Hotel.first(:id => params[:id])
  erb :detail
end
=begin
  property :id, Serial
  property :title, String
  property :description, String, :length => 100
  property :image_src, String, :length => 100
  property :start_at, Date
  property :end_at, Date
  property :size, Integer
=end
post '/add_hotel' do
  start_date= params[:hotel_start]
  end_date= params[:hotel_end]
  h = Hotel.new
  h.title = params[:hotel_title]
  h.description = params[:hotel_description]
  h.image_src = params[:hotel_image_location]
  h.start_at = Date::strptime(start_date, '%m/%d/%Y')
  h.end_at = Date::strptime(end_date, '%m/%d/%Y')
  h.size = params[:hotel_size]
  if !h.save
    h.errors
  else
    1.upto(h.size) do |x|
      h.start_at.upto(h.end_at) do |y|
        t = Ticket.new
        t.user_id = -1
        t.hotel_id = h.id
        t.reservation_date =y
        t.save
      end
    end
    redirect '/admin'
    end
end

get '/init_database' do  #QQQQQQQQQQQQQQQQQQQQQQQQ

    msg = ""
    n_user = User.new
    n_user.user_email = "admin@admin.com"
    md5_password = Digest::MD5.hexdigest("asdf")
    n_user.user_password = md5_password
    n_user.admin = true
    n_user.save
################################ Add Hotel
=begin
    1.upto(5) do
    hotel = Hotel.new
    hotel.title = "전망좋은 호텔입니다."
    hotel.description = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
    hotel.image_src = "http://imagizer.imageshack.us/v2/150x100q90/907/wkvloM.jpg"
    if !hotel.save
      hotel.errors.each do |x|
      msg << x.join
      end
    end
    end
=end

    if msg.empty?
    redirect '/'
    else
      msg
      end

end

post '/reservation' do 
  start_date = params[:start_date]
  end_date = params[:end_date]

  start_date.upto(end_date) do |d|
  t = Ticket.all(:hotel_id => params[:hotel_id],
                 :reservation_date => Date::strptime(d,'%m/%d/%Y'),
                 :user_id => -1).first
  if t.nil?
  else
      user = User.first(:user_email => session[:email])
      t.user_id = user.id
      t.save
    end
  end
 redirect '/'
end

get '/destroy_database' do  #QQQQQQQQQQQQQQQQQQQQQ
    User.all.destroy
    Hotel.all.destroy
    redirect '/'
end

get '/forgot_password' do
  
    erb :forgot_password
end

post '/send_new_password_email' do

  u = User.first(:user_email => params[:email_recv])
  if u.nil?
     " 해당 유저가 없습니다."
  else
   temp_pwd = ('a'..'z').to_a.sample(10).join
 
   u.user_password = Digest::MD5.hexdigest(temp_pwd)
   u.save
  RestClient.post "https://api:key-77d607598214e1ca6c7b304d60393feb"\
  "@api.mailgun.net/v2/sandbox538e1d0ede51458cba05e78897dc0ccc.mailgun.org/messages",
  :from => " no-reply <no-reply@hoya.com>",
  :to => u.user_email,
  :subject => "새로 발급한 비밀번호 입니다.",
  :text => "너의 새로운 비밀번호는 #{ temp_pwd } 입니다."
    erb :email_send
  end
end
