class User < ActiveRecord::Base

  require 'google/api_client'
  require 'net/http'
  require 'json'

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable, :omniauth_providers => [:google_oauth2]

  def self.from_omniauth(access_token)

    data = access_token.info
    logger.debug data
    logger.debug access_token.credentials

    user = User.where(:email => data["email"]).first

    unless user
        user = User.create(
           #name: data["name"],
           email: data["email"],
           provider: access_token.provider,
           uid: access_token.uid,
           token: access_token.credentials.token,
           refresh_token: access_token.credentials.refresh_token,
           token_expires_at: Time.at(access_token.credentials.expires_at).to_datetime,
           password: Devise.friendly_token[0,20],
           image_url: access_token.info.image
        )
        user.update_timezone
    end

    user

  end

  # helper
  def time_now
    Time.now.in_time_zone(self.timezone)
  end

  def create_event(h = {})

    event = {
      summary: 'New Event Title',
      description: '',
      location: '',
      start: {
        dateTime: self.time_now.to_datetime.rfc3339
      },
      end: {
        dateTime: (self.time_now + 1.hour).to_datetime.rfc3339
      }
    }.merge(h)

    client = Google::APIClient.new
    client.authorization.access_token = self.fresh_token
    service = client.discovered_api('calendar', 'v3')

    client.execute(:api_method => service.events.insert,
                   :parameters => {'calendarId' => self.email, 'sendNotifications' => true},
                   :body => JSON.dump(event),
                   :headers => {'Content-Type' => 'application/json'})

  end

  def update_timezone

    client = Google::APIClient.new
    client.authorization.access_token = self.fresh_token
    service = client.discovered_api('calendar', 'v3')

    results = client.execute(:api_method => service.calendars.get, :parameters => {'calendarId' => self.email}, :headers => {'Content-Type' => 'application/json'})
    z = results.data.timeZone

    unless z.nil?
      self.update!(:timezone => z)
    end

  end

  def get_busy

    client = Google::APIClient.new
    client.authorization.access_token = self.fresh_token
    service = client.discovered_api('calendar', 'v3')

    data = { "timeMin" => self.time_now.to_datetime.rfc3339, "timeMax" => (self.time_now + 1.week).to_datetime.rfc3339, "items" => [ { "id" => self.email } ] }
    results = client.execute(:api_method => service.freebusy.query, :parameters => {'calendarId' => self.email}, :body => JSON.dump(data), :headers => {'Content-Type' => 'application/json'})

    results.data.calendars.as_json[self.email]['busy']

  end

  def get_free_interval(busy = [])

    #busy = self.get_busy
    interval = nil

    s = (self.time_now + 1.hour).beginning_of_hour

    while s < (self.time_now + 1.week) do

      e = s + 1.hour

      # проверяем, что дата начала и дата окончания не попадают в рабочее время и выходные
      if s.hour.between?(10, 18) && e.hour.between?(10, 18) && ![0, 6].include?(s.wday) && ![0, 6].include?(e.wday)

        busy_matches = 0

        unless busy.nil?

          busy.each{|row|

            busy_start = DateTime.parse(row['start']).in_time_zone(self.timezone)
            busy_end   = DateTime.parse(row['end']).in_time_zone(self.timezone) - 1.minute

            # проверяем, что дата начала и дата окончания не попадают в "занятый" интервал
            if s.between?(busy_start, busy_end) || e.between?(busy_start, busy_end)
              busy_matches = busy_matches + 1
              break
            end

          }

        end

        if busy_matches == 0
          # мы не попали ни в один busy-период
          interval = {
            start: {
              dateTime: s.to_datetime.rfc3339
            },
            end: {
              dateTime: e.to_datetime.rfc3339
            }
          }
        end

      end

      break unless interval.nil?

      s = s + 1.hour

    end

    interval

  end

  # https://www.twilio.com/blog/2014/09/gmail-api-oauth-rails.html

  def token_to_params
    {'refresh_token' => self.refresh_token,
     'client_id' => ENV['GOOGLE_CLIENT_ID'],
     'client_secret' => ENV['GOOGLE_CLIENT_SECRET'],
     'grant_type' => 'refresh_token'
    }
  end

  def request_token_from_google
    url = URI("https://accounts.google.com/o/oauth2/token")
    Net::HTTP.post_form(url, self.token_to_params)
  end

  def refresh_token_now
    response = self.request_token_from_google
    data = JSON.parse(response.body)
    self.update_attributes(
      token: data['access_token'],
      token_expires_at: Time.now + (data['expires_in'].to_i).seconds
    )
  end

  def token_expired?
    self.token_expires_at.to_i < Time.now.to_i
  end

  def fresh_token
    refresh_token_now if token_expired?
    self.token
  end

end
