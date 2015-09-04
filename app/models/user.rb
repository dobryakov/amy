class User < ActiveRecord::Base

  require 'google/api_client'

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
           password: Devise.friendly_token[0,20]
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
      description: 'The description',
      location: 'Location',
      start: {
        dateTime: self.time_now.to_datetime.rfc3339
      },
      end: {
        dateTime: (self.time_now + 1.hour).to_datetime.rfc3339
      }
    }.merge(h)

    client = Google::APIClient.new
    client.authorization.access_token = self.token
    service = client.discovered_api('calendar', 'v3')

    client.execute(:api_method => service.events.insert,
                   :parameters => {'calendarId' => self.email, 'sendNotifications' => true},
                   :body => JSON.dump(event),
                   :headers => {'Content-Type' => 'application/json'})

  end

  def update_timezone

    client = Google::APIClient.new
    client.authorization.access_token = self.token
    service = client.discovered_api('calendar', 'v3')

    results = client.execute(:api_method => service.calendars.get, :parameters => {'calendarId' => self.email}, :headers => {'Content-Type' => 'application/json'})
    z = results.data.timeZone

    unless z.nil?
      self.update!(:timezone => z)
    end

  end

  def get_busy

    client = Google::APIClient.new
    client.authorization.access_token = self.token
    service = client.discovered_api('calendar', 'v3')

    data = { "timeMin" => self.time_now.to_datetime.rfc3339, "timeMax" => (self.time_now + 1.week).to_datetime.rfc3339, "items" => [ { "id" => self.email } ] }
    results = client.execute(:api_method => service.freebusy.query, :parameters => {'calendarId' => self.email}, :body => JSON.dump(data), :headers => {'Content-Type' => 'application/json'})

    results.data.calendars.as_json[self.email]['busy']

  end

  def get_free_interval

    busy = self.get_busy
    interval = nil

    unless busy.nil?

      s = (self.time_now + 1.hour).beginning_of_hour

      while s < (self.time_now + 1.week) do

        e = s + 1.hour

        busy.each{|row|

          busy_start = Date.parse(row['start'])
          busy_end   = Date.parse(row['end'])

          # проверяем, что дата начала и дата окончания не попадают в "занятый" интервал
          # а так же, что они не попадают в рабочее время и выходные
          if !s.between?(busy_start, busy_end) && !e.between?(busy_start, busy_end) && s.hour.between?(10, 14) && e.hour.between?(10, 14) && ![0, 6].include?(s.wday) && ![0, 6].include?(e.wday)
            interval = {
              start: {
                dateTime: s.to_datetime.rfc3339
              },
              end: {
                dateTime: e.to_datetime.rfc3339
              }
            }
            break
          end
        }

        break unless interval.nil?

        s = s + 1.hour

      end

    end

    interval

  end

end
