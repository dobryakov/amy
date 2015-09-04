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

    Mail.all.each{|letter|

      from = letter.from.first
      subject = letter.subject

      user = User.where(:email => from).first

      unless user.nil?
        interval = user.get_free_interval
        unless interval.nil?
          user.create_event(interval.merge({
                                             summary: subject
                                           }))
        end
      end

    }

  end

end
