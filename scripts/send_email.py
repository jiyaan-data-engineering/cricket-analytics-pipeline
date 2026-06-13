#!/usr/bin/env python3
"""
Send deployment notification emails via Gmail SMTP.
"""

import smtplib
import sys
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime

def send_email(
    smtp_server="smtp.gmail.com",
    smtp_port=465,
    sender_email="jiyaan.institute@gmail.com",
    sender_password=None,
    recipient_email="jiyaan.institute@gmail.com",
    subject="",
    body="",
    is_html=False
):
    """Send email via Gmail SMTP with SSL."""

    if not sender_password:
        raise ValueError("GMAIL_APP_PASSWORD environment variable not set")

    try:
        print(f"🔐 Connecting to {smtp_server}:{smtp_port}...")

        # Create SMTP connection with SSL
        server = smtplib.SMTP_SSL(smtp_server, smtp_port, timeout=10)

        print("🔑 Authenticating...")
        server.login(sender_email, sender_password)

        # Create email message
        if is_html:
            msg = MIMEMultipart('alternative')
        else:
            msg = MIMEText(body, 'plain', 'utf-8')

        msg['Subject'] = subject
        msg['From'] = f"GitHub Actions <{sender_email}>"
        msg['To'] = recipient_email
        msg['Date'] = datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S +0000')

        # Attach body for multipart emails
        if is_html:
            msg.attach(MIMEText(body, 'plain', 'utf-8'))

        print(f"📧 Sending email to {recipient_email}...")
        server.sendmail(sender_email, recipient_email, msg.as_string())

        print("✅ Email sent successfully!")
        server.quit()
        return True

    except smtplib.SMTPAuthenticationError as e:
        print(f"❌ Authentication failed: {e}")
        print("⚠️  Check your email password (GMAIL_APP_PASSWORD)")
        return False
    except smtplib.SMTPException as e:
        print(f"❌ SMTP error: {e}")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='Send deployment notification email')
    parser.add_argument('--subject', required=True, help='Email subject')
    parser.add_argument('--body-file', required=True, help='Path to email body file')
    parser.add_argument('--to', default='jiyaan.institute@gmail.com', help='Recipient email')
    parser.add_argument('--from', default='jiyaan.institute@gmail.com', dest='sender', help='Sender email')
    parser.add_argument('--html', action='store_true', help='Body is HTML')

    args = parser.parse_args()

    # Read email body from file
    try:
        with open(args.body_file, 'r') as f:
            body = f.read()
    except FileNotFoundError:
        print(f"❌ Email body file not found: {args.body_file}")
        sys.exit(1)

    # Get password from environment variable
    password = os.environ.get('GMAIL_APP_PASSWORD')

    # Send email
    success = send_email(
        sender_email=args.sender,
        sender_password=password,
        recipient_email=args.to,
        subject=args.subject,
        body=body,
        is_html=args.html
    )

    sys.exit(0 if success else 1)
