#!/usr/bin/env python
"""
Test script to check SendGrid email configuration
Run this on the VPS: python test_email_sendgrid.py
"""
import os
import sys
import django

# Setup Django
sys.path.insert(0, '/var/www/auditra/backend')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'auditra_backend.settings')
django.setup()

from django.conf import settings
from django.core.mail import send_mail
import traceback

print("=" * 60)
print("SendGrid Email Configuration Test")
print("=" * 60)
print(f"EMAIL_BACKEND: {settings.EMAIL_BACKEND}")
print(f"SENDGRID_API_KEY: {'SET (' + settings.SENDGRID_API_KEY[:20] + '...)' if settings.SENDGRID_API_KEY else 'NOT SET'}")
print(f"DEFAULT_FROM_EMAIL: {settings.DEFAULT_FROM_EMAIL}")
print("=" * 60)

# Test email sending
test_email = input("Enter your email address to test: ").strip()

if not test_email:
    print("No email provided. Exiting.")
    sys.exit(1)

print(f"\nAttempting to send test email to: {test_email}")

try:
    result = send_mail(
        subject='Auditra - SendGrid Test Email',
        message='This is a test email to verify SendGrid is working correctly.',
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[test_email],
        fail_silently=False,
    )
    print("\n✅ SUCCESS: Email sent successfully!")
    print("Check your inbox (and spam folder) for the test email.")
    print("\nAlso check SendGrid dashboard: https://app.sendgrid.com → Activity → Email Activity")
except Exception as e:
    print(f"\n❌ ERROR: Failed to send email")
    print(f"Error type: {type(e).__name__}")
    print(f"Error message: {str(e)}")
    print("\nFull traceback:")
    traceback.print_exc()
    print("\n" + "=" * 60)
    print("Common issues:")
    print("1. SendGrid API key is invalid or expired")
    print("2. Sender email not verified in SendGrid")
    print("3. SendGrid account suspended or rate limited")
    print("4. Check SendGrid dashboard for more details")
    print("=" * 60)

