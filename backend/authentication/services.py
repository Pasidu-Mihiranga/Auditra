"""
Email service for sending account credentials and notifications
"""
import logging
from django.core.mail import send_mail
from django.conf import settings
from django.template.loader import render_to_string
from django.utils.html import strip_tags

logger = logging.getLogger(__name__)


class EmailService:
    """Service for sending emails via SendGrid API"""

    @staticmethod
    def send_account_credentials(email, username, password, user_type, name=None, role=None, salary=None):
        """
        Send account credentials to newly created user

        Args:
            email: Recipient email address
            username: Username for login
            password: System-generated password
            user_type: 'client', 'agent', or 'employee'
            name: User's name (optional)
            role: Role display name (optional, e.g. 'Client', 'Field Officer')
            salary: Basic salary amount (optional)
        """
        type_map = {'client': 'Client', 'agent': 'Agent', 'employee': 'Employee'}
        user_type_display = type_map.get(user_type, user_type.title() if user_type else 'User')
        recipient_name = name if name else user_type_display

        login_url = getattr(settings, 'FRONTEND_URL', 'http://localhost:5173') + '/login'

        subject = f'Welcome to Auditra - Your {user_type_display} Account Credentials'

        # Build detail rows
        detail_rows = f"""
                        <p style="margin: 10px 0;"><strong>Name:</strong> {recipient_name}</p>
                        <p style="margin: 10px 0;"><strong>Username:</strong> {username}</p>
                        <p style="margin: 10px 0;"><strong>Password:</strong> {password}</p>"""

        if role:
            detail_rows += f"""
                        <p style="margin: 10px 0;"><strong>Role:</strong> {role}</p>"""

        if salary is not None and salary > 0:
            detail_rows += f"""
                        <p style="margin: 10px 0;"><strong>Basic Salary:</strong> Rs. {salary:,.2f}</p>"""

        html_message = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <div style="background-color: #1565C0; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0;">
                    <h1 style="margin: 0;">Welcome to Auditra</h1>
                </div>
                <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 5px 5px;">
                    <p>Dear {recipient_name},</p>
                    <p>Your {user_type_display.lower()} account has been created for the Auditra system. You can now log in using the credentials below:</p>

                    <div style="background-color: white; padding: 20px; border-left: 4px solid #1565C0; margin: 20px 0;">
                        {detail_rows}
                    </div>

                    <div style="text-align: center; margin: 30px 0;">
                        <a href="{login_url}" style="display: inline-block; background-color: #1565C0; color: white; padding: 14px 32px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px;">Login to System</a>
                    </div>

                    <p style="color: #d9534f; font-weight: bold;">Important: Please keep these credentials secure.</p>
                    <p>For your security, you will be required to change your password after your first login.</p>

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
        role_line = f"\nRole: {role}" if role else ""
        salary_line = f"\nBasic Salary: Rs. {salary:,.2f}" if salary and salary > 0 else ""
        plain_message = f"""
Dear {recipient_name},

Your {user_type_display.lower()} account has been created for the Auditra system. You can now log in using the credentials below:

Name: {recipient_name}
Username: {username}
Password: {password}{role_line}{salary_line}

Login here: {login_url}

IMPORTANT: Please keep these credentials secure.

For your security, you will be required to change your password after your first login.

Best regards,
The Auditra Team

---
This is an automated message. Please do not reply to this email.
        """

        try:
            logger.info(f"Attempting to send credentials email to {email} for {user_type} {username}")

            send_mail(
                subject=subject,
                message=plain_message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                html_message=html_message,
                fail_silently=False,
            )
            logger.info(f"Successfully sent credentials email to {email} for {user_type} {username}")
            return True
        except Exception as e:
            logger.error(f"Error sending email to {email}: {str(e)}", exc_info=True)
            return False

    @staticmethod
    def send_submission_confirmation(email, name, submission_type, project_title=None):
        """
        Send confirmation email when a form submission is received.

        Args:
            email: Recipient email address
            name: Submitter's name
            submission_type: 'client', 'agent', or 'employee'
            project_title: Project title (for client submissions)
        """
        type_map = {'client': 'Client Registration', 'agent': 'Agent', 'employee': 'Employee Application'}
        type_display = type_map.get(submission_type, 'Registration')
        recipient_name = name or 'Applicant'

        subject = f'Auditra - {type_display} Submission Received'

        project_line = ''
        if project_title:
            project_line = f'<p style="margin: 10px 0;"><strong>Project:</strong> {project_title}</p>'

        html_message = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <div style="background-color: #1565C0; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0;">
                    <h1 style="margin: 0;">Submission Received</h1>
                </div>
                <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 5px 5px;">
                    <p>Dear {recipient_name},</p>
                    <p>Thank you for submitting your {type_display.lower()} form. We have received your submission and it is currently under review.</p>
                    <div style="background-color: white; padding: 20px; border-left: 4px solid #1565C0; margin: 20px 0;">
                        <p style="margin: 10px 0;"><strong>Submission Type:</strong> {type_display}</p>
                        {project_line}
                        <p style="margin: 10px 0;"><strong>Status:</strong> Pending Review</p>
                    </div>
                    <p>Our team will review your submission and you will be notified via email once it has been processed.</p>
                    <p style="margin-top: 30px;">Best regards,<br>The Auditra Team</p>
                </div>
                <div style="text-align: center; padding: 20px; color: #999; font-size: 12px;">
                    <p>This is an automated message. Please do not reply to this email.</p>
                </div>
            </div>
        </body>
        </html>
        """

        project_text = f"\nProject: {project_title}" if project_title else ""
        plain_message = f"""
Dear {recipient_name},

Thank you for submitting your {type_display.lower()} form. We have received your submission and it is currently under review.

Submission Type: {type_display}{project_text}
Status: Pending Review

Our team will review your submission and you will be notified via email once it has been processed.

Best regards,
The Auditra Team
        """

        try:
            logger.info(f'Sending submission confirmation to {email}')
            send_mail(
                subject=subject,
                message=plain_message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                html_message=html_message,
                fail_silently=False,
            )
            return True
        except Exception as e:
            logger.error(f'Error sending submission confirmation to {email}: {str(e)}', exc_info=True)
            return False

    @staticmethod
    def send_status_update(submission, new_status, coordinator_name=None):
        """Send status update email to client and agent when submission status changes."""
        status_display = dict(submission.STATUS_CHOICES).get(new_status, new_status).title()
        recipients = [submission.email]
        if submission.agent_email:
            recipients.append(submission.agent_email)

        subject = f'Auditra - Submission Status Update: {status_display}'

        coordinator_line = ''
        if new_status == 'assigned' and coordinator_name:
            coordinator_line = f'<p style="margin: 10px 0;"><strong>Assigned Coordinator:</strong> {coordinator_name}</p>'

        client_name = submission.first_name or 'Client'

        html_message = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <div style="background-color: #1565C0; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0;">
                    <h1 style="margin: 0;">Submission Status Update</h1>
                </div>
                <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 5px 5px;">
                    <p>Dear {client_name},</p>
                    <p>Your submission for project <strong>{submission.project_title}</strong> has been updated.</p>
                    <div style="background-color: white; padding: 20px; border-left: 4px solid #1565C0; margin: 20px 0;">
                        <p style="margin: 10px 0;"><strong>New Status:</strong> {status_display}</p>
                        {coordinator_line}
                    </div>
                    <p style="margin-top: 30px;">Best regards,<br>The Auditra Team</p>
                </div>
                <div style="text-align: center; padding: 20px; color: #999; font-size: 12px;">
                    <p>This is an automated message. Please do not reply to this email.</p>
                </div>
            </div>
        </body>
        </html>
        """

        plain_message = f'Your submission for {submission.project_title} status: {status_display}'

        try:
            logger.info(f'Sending status update email to {recipients}')
            send_mail(
                subject=subject,
                message=plain_message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=recipients,
                html_message=html_message,
                fail_silently=False,
            )
            return True
        except Exception as e:
            logger.error(f'Error sending status update email: {str(e)}', exc_info=True)
            return False

    @staticmethod
    def send_employee_status_update(submission, new_status):
        """Send status update email to employee applicant when submission status changes."""
        status_display = dict(submission.STATUS_CHOICES).get(new_status, new_status).title()
        applicant_name = f'{submission.first_name or ""} {submission.last_name or ""}'.strip() or 'Applicant'

        if not submission.email:
            return False

        subject = f'Auditra - Application Status Update: {status_display}'

        html_message = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <div style="background-color: #1565C0; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0;">
                    <h1 style="margin: 0;">Application Status Update</h1>
                </div>
                <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 5px 5px;">
                    <p>Dear {applicant_name},</p>
                    <p>Your employee application at Auditra has been updated.</p>
                    <div style="background-color: white; padding: 20px; border-left: 4px solid #1565C0; margin: 20px 0;">
                        <p style="margin: 10px 0;"><strong>New Status:</strong> {status_display}</p>
                    </div>
                    <p>If you have any questions, please contact our HR team.</p>
                    <p style="margin-top: 30px;">Best regards,<br>The Auditra Team</p>
                </div>
                <div style="text-align: center; padding: 20px; color: #999; font-size: 12px;">
                    <p>This is an automated message. Please do not reply to this email.</p>
                </div>
            </div>
        </body>
        </html>
        """

        plain_message = f'Dear {applicant_name}, your employee application status has been updated to: {status_display}.'

        try:
            logger.info(f'Sending employee status update email to {submission.email}')
            send_mail(
                subject=subject,
                message=plain_message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[submission.email],
                html_message=html_message,
                fail_silently=False,
            )
            return True
        except Exception as e:
            logger.error(f'Error sending employee status update email: {str(e)}', exc_info=True)
            return False

    @staticmethod
    def send_project_assignment_notification(email, name, project_title, role_in_project, coordinator_name=None):
        """
        Send email notification when a user is assigned to a project.

        Args:
            email: Recipient email
            name: Recipient name
            project_title: Title of the project
            role_in_project: Their role in the project (e.g. 'Client', 'Agent')
            coordinator_name: Name of the coordinator (optional)
        """
        recipient_name = name or 'User'

        subject = f'Auditra - You Have Been Assigned to a Project'

        coordinator_line = ''
        if coordinator_name:
            coordinator_line = f'<p style="margin: 10px 0;"><strong>Coordinator:</strong> {coordinator_name}</p>'

        login_url = getattr(settings, 'FRONTEND_URL', 'http://localhost:5173') + '/login'

        html_message = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <div style="background-color: #1565C0; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0;">
                    <h1 style="margin: 0;">Project Assignment</h1>
                </div>
                <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 5px 5px;">
                    <p>Dear {recipient_name},</p>
                    <p>You have been assigned to a new project on the Auditra system.</p>
                    <div style="background-color: white; padding: 20px; border-left: 4px solid #1565C0; margin: 20px 0;">
                        <p style="margin: 10px 0;"><strong>Project:</strong> {project_title}</p>
                        <p style="margin: 10px 0;"><strong>Your Role:</strong> {role_in_project}</p>
                        {coordinator_line}
                    </div>
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="{login_url}" style="display: inline-block; background-color: #1565C0; color: white; padding: 14px 32px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px;">View Project</a>
                    </div>
                    <p style="margin-top: 30px;">Best regards,<br>The Auditra Team</p>
                </div>
                <div style="text-align: center; padding: 20px; color: #999; font-size: 12px;">
                    <p>This is an automated message. Please do not reply to this email.</p>
                </div>
            </div>
        </body>
        </html>
        """

        plain_message = f"""
Dear {recipient_name},

You have been assigned to a new project on the Auditra system.

Project: {project_title}
Your Role: {role_in_project}
{f'Coordinator: {coordinator_name}' if coordinator_name else ''}

Login to view the project: {login_url}

Best regards,
The Auditra Team
        """

        try:
            logger.info(f'Sending project assignment notification to {email}')
            send_mail(
                subject=subject,
                message=plain_message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                html_message=html_message,
                fail_silently=False,
            )
            return True
        except Exception as e:
            logger.error(f'Error sending project assignment email to {email}: {str(e)}', exc_info=True)
            return False

    @staticmethod
    def send_otp_email(email, otp):
        """Send OTP code for password reset."""
        subject = 'Auditra - Password Reset OTP'

        html_message = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <div style="background-color: #1565C0; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0;">
                    <h1 style="margin: 0;">Password Reset</h1>
                </div>
                <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 5px 5px;">
                    <p>You requested a password reset for your Auditra account.</p>
                    <p>Use the following OTP code to reset your password:</p>
                    <div style="background-color: white; padding: 20px; border-left: 4px solid #1565C0; margin: 20px 0; text-align: center;">
                        <p style="font-size: 32px; font-weight: bold; letter-spacing: 8px; margin: 0; color: #1565C0;">{otp}</p>
                    </div>
                    <p style="color: #d9534f; font-weight: bold;">This code expires in 10 minutes.</p>
                    <p>If you did not request this, please ignore this email.</p>
                    <p style="margin-top: 30px;">Best regards,<br>The Auditra Team</p>
                </div>
                <div style="text-align: center; padding: 20px; color: #999; font-size: 12px;">
                    <p>This is an automated message. Please do not reply to this email.</p>
                </div>
            </div>
        </body>
        </html>
        """

        plain_message = f"Your Auditra password reset OTP is: {otp}\nThis code expires in 10 minutes."

        try:
            logger.info(f'Sending OTP email to {email}')
            send_mail(
                subject=subject,
                message=plain_message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                html_message=html_message,
                fail_silently=False,
            )
            return True
        except Exception as e:
            logger.error(f'Error sending OTP email to {email}: {str(e)}', exc_info=True)
            return False
