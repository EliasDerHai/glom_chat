import app/environment
import gcourier/message
import gcourier/smtp
import gleam/option.{Some}

pub fn send_confirmation_mail(recipient_email: String, confirmation_url: String) {
  let environment.SenderEmailInfos(
    sender_email,
    sender_email_name,
    sender_password,
  ) = environment.get_sender_email_infos()

  let subject = "Confirm your glom-chat account"
  let body = "<!DOCTYPE html>
    <html lang='en'>
        <head>
            <meta charset='UTF-8'>
            <meta name='viewport' content='width=device-width, initial-scale=1.0'>
            <title>Confirm your account</title>
            <style>
                body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; background-color: #f8f9fa; }
                .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px 30px; text-align: center; }
                .header h1 { margin: 0; font-size: 28px; font-weight: 600; }
                .content { padding: 40px 30px; }
                .welcome { font-size: 18px; margin-bottom: 20px; color: #2c3e50; }
                .message { margin-bottom: 30px; color: #555; font-size: 16px; }
                .cta-button { display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 16px 32px; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 20px 0; transition: transform 0.2s ease; }
                .cta-button:hover { transform: translateY(-1px); }
                .footer { background-color: #f8f9fa; padding: 30px; text-align: center; border-top: 1px solid #e9ecef; }
                .footer p { margin: 0; color: #6c757d; font-size: 14px; }
                .security-note { background-color: #f8f9fa; border-left: 4px solid #667eea; padding: 15px 20px; margin: 20px 0; border-radius: 0 4px 4px 0; }
                .security-note p { margin: 0; font-size: 14px; color: #555; }
            </style>
        </head>
        <body>
            <div class='container'>
                <div class='header'>
                    <h1>Welcome to glom-chat</h1>
                </div>
                <div class='content'>
                    <p class='welcome'>Hello,</p>
                    <p class='message'>
                        Thank you for creating an account with glom-chat. To complete your registration and secure your account,
                        please confirm your email address by clicking the button below.
                    </p>
                    <div style='text-align: center;'>
                        <a href='" <> confirmation_url <> "' class='cta-button'>Confirm Account</a>
                    </div>
                    <div class='security-note'>
                        <p><strong>Security Notice:</strong> This confirmation link will expire for your security. If you did not create an account with us, please disregard this email.</p>
                    </div>
                    <p style='margin-top: 30px; color: #666; font-size: 14px;'>
                        If the button above does not work, please copy and paste the following link into your browser:<br>
                        <a href='" <> confirmation_url <> "' style='color: #667eea; word-break: break-all;'>" <> confirmation_url <> "</a>
                    </p>
                </div>
                <div class='footer'>
                    <p>This email was sent by glom-chat.</p>
                    <p>For support inquiries, you can respond to this mail, but you will probably be ignored... XD</p>
                </div>
            </div>
        </body>
    </html>"

  let msg =
    message.build()
    |> message.set_from(sender_email, Some(sender_email_name))
    |> message.add_recipient(recipient_email, message.To)
    |> message.set_subject(subject)
    |> message.set_html(body)

  smtp.send("smtp.gmail.com", 587, Some(#(sender_email, sender_password)), msg)
}
