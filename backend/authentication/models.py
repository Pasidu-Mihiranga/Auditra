from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver


class UserRole(models.Model):
    """User Role Model for Role-Based Access Control"""
    
    ROLE_CHOICES = [
        ('admin', 'Admin'),
        ('coordinator', 'Coordinator'),
        ('field_officer', 'Field Officer'),
        ('accessor', 'Accessor'),
        ('senior_valuer', 'Senior Valuer'),
        ('md_gm', 'MD/GM'),
        ('hr_staff', 'HR Staff'),
        ('general_employee', 'General Employee'),
        ('client', 'Client'),
        ('agent', 'Agent'),
        ('unassigned', 'Unassigned'),
    ]
    
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='role')
    role = models.CharField(max_length=50, choices=ROLE_CHOICES, default='unassigned')
    assigned_by = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        related_name='assigned_roles'
    )
    assigned_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)
    password_changed = models.BooleanField(
        default=False,
        help_text='Whether the user has changed their password (for clients/agents)'
    )
    
    class Meta:
        db_table = 'user_roles'
        verbose_name = 'User Role'
        verbose_name_plural = 'User Roles'
    
    def __str__(self):
        return f"{self.user.username} - {self.get_role_display()}"
    
    @property
    def role_display(self):
        return self.get_role_display()


@receiver(post_save, sender=User)
def create_user_role(sender, instance, created, **kwargs):
    """Automatically create UserRole when User is created"""
    if created:
        UserRole.objects.create(user=instance, role='unassigned')


@receiver(post_save, sender=User)
def save_user_role(sender, instance, **kwargs):
    """Save UserRole when User is saved"""
    if hasattr(instance, 'role'):
        instance.role.save()
