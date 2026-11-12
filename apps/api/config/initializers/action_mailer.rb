# Action Mailer logs the recipient, a delivery error message that can repeat
# the address, and, at debug level, the whole message, with the reset link.
# None of that may reach the logs (design 4.7), so its log lines are turned
# off. A failed delivery still raises in the job, whose error handler records
# only the exception class.
# Action Mailer attaches its subscriber when ActionMailer::Base loads.
ActiveSupport.on_load(:action_mailer) { ActionMailer::LogSubscriber.detach_from :action_mailer }
