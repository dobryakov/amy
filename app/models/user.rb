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

    user = User.where(:email => data["email"]).first

    unless user
        user = User.create(
           #name: data["name"],
           email: data["email"],
           provider: access_token.provider,
           uid: access_token.uid,
           token: access_token.credentials.token,
           password: Devise.friendly_token[0,20]
        )
    end

    user

  end

  def create_event(h = {})

    event = {
      summary: 'New Event Title',
      description: 'The description',
      location: 'Location',
      start: {
        dateTime: Time.now.to_datetime.rfc3339
      },
      end: {
        dateTime: (Time.now + 1.hour).to_datetime.rfc3339
      }
    }.merge(h)

    client = Google::APIClient.new
    client.authorization.access_token = current_user.token
    service = client.discovered_api('calendar', 'v3')

    client.execute(:api_method => service.events.insert,
                   :parameters => {'calendarId' => current_user.email, 'sendNotifications' => true},
                   :body => JSON.dump(event),
                   :headers => {'Content-Type' => 'application/json'})

  end

end
