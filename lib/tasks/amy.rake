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

      from = letter.from.first
      user = User.where(:email => from).first

      unless user.nil?

        subject = letter.subject.gsub! /Re: /, ''
        subject = 'New event from amy' if subject.to_s == ''

        attendees = letter.to.reject{|i| i == ENV['POP3_USER']}.push(from).map{|i| { 'email' => i } }

        Rails.logger.debug attendees

        interval = user.get_free_interval

        unless interval.nil?
          params = interval.merge({ summary: subject, attendees: attendees })
          #p params
          user.create_event(params)
        end

      end

    end

  end

end
