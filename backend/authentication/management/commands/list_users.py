"""
List all users (username, email, role). Passwords are hashed and cannot be retrieved.
"""
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User


class Command(BaseCommand):
    help = "List all usernames, emails, and roles (passwords are hashed and not retrievable)"

    def handle(self, *args, **options):
        users = User.objects.select_related("role").order_by("id")
        if not users.exists():
            self.stdout.write("No users in database.")
            return
        self.stdout.write(f"{'ID':<6} {'Username':<25} {'Email':<35} {'Role':<20} {'Staff'}")
        self.stdout.write("-" * 95)
        for u in users:
            role = getattr(u, "role", None)
            role_str = role.get_role_display() if role else "—"
            email = (u.email or "")[:34]
            staff = "Yes" if u.is_staff else "No"
            self.stdout.write(f"{u.pk:<6} {u.username:<25} {email:<35} {role_str:<20} {staff}")
