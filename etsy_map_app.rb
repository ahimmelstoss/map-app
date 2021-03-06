class EtsyMapApp < Sinatra::Base

  set :public_folder => "public", :static => true

  enable :sessions

  before do
    Etsy.api_key = ENV['API_KEY']
    Etsy.api_secret = ENV['SECRET_KEY']
    Etsy.environment = :production
    Etsy.protocol = 'https'
    Etsy.callback_url = 'http://etsy-map-app.herokuapp.com/authorize'
  end

  get '/' do
    if session[:access_token].nil? && session[:access_secret].nil?
      erb :index
    else
      redirect '/map'
    end
  end

  get '/login' do
    request_token = Etsy.request_token
    session[:request_token]  = request_token.token
    session[:request_secret] = request_token.secret
    redirect Etsy.verification_url
  end

  get '/authorize' do
    access_token = Etsy.access_token(
      session[:request_token],
      session[:request_secret],
      params[:oauth_verifier]
    )
    session[:access_token] = access_token.token
    session[:access_secret] = access_token.secret
    redirect '/map'
    # access_token.token and access_token.secret can now be saved for future API calls
  end

  get "/map" do
    if session[:access_token].nil? && session[:access_secret].nil?
      redirect '/'
    else
      access = {
        :access_token => session[:access_token], 
        :access_secret => session[:access_secret]
      }

      @user = Etsy.myself(access[:access_token], access[:access_secret])
      @user = Etsy::Request.get('/users/' + @user.id.to_s, access.merge(:limit => 1)).to_hash["results"]
      @transactions = Etsy::Request.get('/users/' + @user[0]['user_id'].to_s + '/transactions', access.merge(:limit => 20)).to_hash["results"]
      @data = []
      @transactions.each do |transaction|
        hash = {:title => transaction['title']}
        sellers_profile = Etsy::Request.get('/users/'+transaction['seller_user_id'].to_s+'/profile', access.merge(:limit => 20)).to_hash["results"]
        hash[:seller_user_id] = transaction['seller_user_id']
        hash[:location] = "#{sellers_profile[0]['city']}, #{sellers_profile[0]['region']}, #{Etsy::Request.get('/countries/' + sellers_profile[0]['country_id'].to_s, access.merge(:limit => 1)).to_hash["results"][0]['name'].to_s}"
        hash[:url] = transaction['url']
        @data << hash
      end
      @data
      erb :map
    end
  end

end
