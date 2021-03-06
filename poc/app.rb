# OAUTH2
# http://tools.ietf.org/html/rfc6749#section-1.2
# https://canvas.instructure.com/doc/api/file.oauth.html

require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

require 'json'

Dotenv.load

$account_id     = ENV.fetch 'ACCOUNT_ID'
$api_host       = ENV.fetch 'API_HOST'
$api_port       = ENV.fetch 'API_PORT'
$api_client_id  = ENV.fetch 'API_CLIENT_ID'
$api_client_key = ENV.fetch 'API_CLIENT_KEY'

$last_url = ""

class URLCapture < Faraday::Middleware

  def initialize(app, options = {})
    super(app)
  end

  def call(env)
    $last_url = env[:url]
    @app.call(env)
  end
end

enable :sessions


helpers do
  def h(text)
    Rack::Utils.escape_html(text)
  end
end

def log_faraday_ex
  yield
rescue Faraday::Error => e
  puts "ERROR: #$last_url"
  p e.response
  raise
end

$conn = Faraday.new(url: "http://#$api_host:#$api_port/") do |c|
  c.use Faraday::Request::UrlEncoded
  c.use Faraday::Response::Logger
  c.use URLCapture
  c.use Faraday::Response::RaiseError
  c.adapter :net_http
end

get '/' do
  response_type = "code"
  redirect_uri = url("/grant")
  state = "XXXXX" # FIXME unique ID saved in state, check
                  # session[state] == request[state]

  # request authorization grant
  url = "http://#$api_host:#$api_port/login/oauth2/auth"
  url << "?client_id=#$api_client_id"
  url << "&response_type=#{response_type}"
  url << "&redirect_uri=#{redirect_uri}"
  url << "&state=#{state}"
  redirect url
end

get '/grant' do
  code = request["code"]
  state = request["state"]
  redirect_uri = url("/token")

  res = log_faraday_ex do
    $conn.post "/login/oauth2/token", {
                 client_id: $api_client_id,
                 client_secret: $api_client_key,
                 redirect_uri: redirect_uri,
                 code: code,
               }
  end
  res = JSON.parse res.body
  puts "TOKEN: ", session['access_token']
  session['access_token'] = res['access_token']

  redirect '/courses'
end

get '/courses' do

  @session = session

  $conn.headers['Authorization'] = "Bearer #{session['access_token']}"

  log_faraday_ex do
    res = $conn.get "/api/v1/accounts/#$account_id/courses", {published: true}
    @courses_url = $last_url
    @courses = JSON.parse res.body

    id = @courses.first["id"]
    res = $conn.get "/api/v1/courses/#{id}", {'include[]' => 'syllabus_body'}
    @course_1_url = $last_url
    @course_1 = JSON.parse res.body

    res = $conn.get "/api/v1/courses", {
                      'include' => ['syllabus_body', 'course_progress'],
                    }
    @my_courses_url = $last_url
    @my_courses = JSON.parse res.body

    course_id = @my_courses.first['id']
    res = $conn.get "/api/v1/courses/#{course_id}/modules", {include: %w(items)}
    @modules_url = $last_url
    @modules = JSON.parse res.body

    course_id = @my_courses.first['id']
    res = $conn.get "/api/v1/courses/#{course_id}/front_page"
    @front_page_url = $last_url
    @front_page = JSON.parse res.body

  end

  haml :courses
end

get '/test' do
  haml :test
end
