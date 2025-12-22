"""
Email service for sending account credentials and notifications
"""
from django.core.mail import send_mail
from django.conf import settings
from django.template.loader import render_to_string
from django.utils.html import strip_tags
import logging

logger = logging.getLogger(__name__)


class EmailService:
    """Service for sending emails via SMTP"""
    
    @staticmethod
    def send_account_credentials(email, username, password, user_type, name=None):
        """
        Send account credentials to newly created user
        
        Args:
            email: Recipient email address
            username: Username for login
            password: System-generated password
            user_type: 'client' or 'agent'
            name: User's name (optional)
        """
        user_type_display = 'Client' if user_type == 'client' else 'Agent'
        recipient_name = name if name else user_type_display
        
        subject = f'Welcome to Auditra - Your {user_type_display} Account Credentials'
        
        # Create HTML email content
        html_message = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <div style="background-color: #4A90E2; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0;">
                    <h1 style="margin: 0;">Welcome to Auditra</h1>
                </div>
                <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 5px 5px;">
                    <p>Dear {recipient_name},</p>
                    <p>Your {user_type_display.lower()} account has been created for the Auditra system. You can now log in using the credentials below:</p>
                    
                    <div style="background-color: white; padding: 20px; border-left: 4px solid #4A90E2; margin: 20px 0;">
                        <p style="margin: 10px 0;"><strong>Username:</strong> {username}</p>
                        <p style="margin: 10px 0;"><strong>Password:</strong> {password}</p>
                    </div>
                    
                    <p style="color: #d9534f; font-weight: bold;">⚠️ Important: Please keep these credentials secure.</p>
                    <p>For your security, we recommend changing your password after your first login.</p>
                    
                    <p style="margin-top: 30px;">Best regards,<br>The Auditra Team</p>
                </div>
                <div style="text-align: center; padding: 20px; color: #999; font-size: 12px;">
                    <p>This is an automated message. Please do not reply to this email.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        # Plain text version
        plain_message = f"""
Dear {recipient_name},

Your {user_type_display.lower()} account has been created for the Auditra system. You can now log in using the credentials below:

Username: {username}
Password: {password}

IMPORTANT: Please keep these credentials secure.

For your security, we recommend changing your password after your first login.

Best regards,
The Auditra Team

---
This is an automated message. Please do not reply to this email.
        """
        
        try:
            # Check email configuration
            if not settings.EMAIL_HOST_USER or not settings.EMAIL_HOST_PASSWORD:
                logger.error(f"Email configuration missing: EMAIL_HOST_USER={bool(settings.EMAIL_HOST_USER)}, EMAIL_HOST_PASSWORD={'*' * len(settings.EMAIL_HOST_PASSWORD) if settings.EMAIL_HOST_PASSWORD else 'NOT SET'}")
                return False
            
            if not settings.DEFAULT_FROM_EMAIL:
                logger.error("DEFAULT_FROM_EMAIL is not set")
                return False
            
            logger.info(f"Attempting to send email to {email} for {user_type} {username}")
            logger.debug(f"Email config: HOST={settings.EMAIL_HOST}, PORT={settings.EMAIL_PORT}, FROM={settings.DEFAULT_FROM_EMAIL}")
            
            send_mail(
                subject=subject,
                message=plain_message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                html_message=html_message,
                fail_silently=False,
            )
            logger.info(f"Successfully sent email to {email} for {user_type} {username}")
            return True
        except Exception as e:
            # Log error with full details
            logger.error(f"Error sending email to {email}: {str(e)}", exc_info=True)
            print(f"ERROR sending email to {email}: {str(e)}")
            import traceback
            traceback.print_exc()
            return False

