namespace :amy do

  desc "TODO"
  task fetch_mail: :environment do

    Mail.defaults do
      retriever_method :pop3, :address    => ENV['POP3_HOST'],
                       :port       => 995,
                       :user_name  => ENV['POP3_USER'],
                       :password   => ENV['POP3_PASSWORD'],
                       :enable_ssl => true
    end

    Mail.find_and_delete(:what => :first, :count => 10, :find_and_delete => true, :order => :asc) do |letter|

      Rails.logger.debug letter.as_json

      from = letter.from.first
      user = User.where(:email => from).first

      unless user.nil?

        subject = letter.subject.to_s.gsub /^Re:/, ''
        subject = 'New event from Amy' if subject.to_s == ''

        attendees = letter.to.reject{|i| i == ENV['POP3_USER']}.push(from).map{|i| { 'email' => i } }

        Rails.logger.debug attendees

        # собираем общее свободное время
        busy = []
        letter.to.reject{|i| i == ENV['POP3_USER']}.push(from).each{|e|
          u = User.where(:email => e).last
          busy = busy + u.get_busy unless u.nil?
        }

        Rails.logger.debug busy

        interval = user.get_free_interval(busy)

        unless interval.nil?
          params = interval.merge({ summary: subject, attendees: attendees })
          #p params
          user.create_event(params)
          Rails.logger.debug params.as_json
        end

      end

    end

  end

end
