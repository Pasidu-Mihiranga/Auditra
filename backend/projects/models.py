from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone


class Project(models.Model):
    """Project model for coordinators to create and manage projects"""
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    ]
    
    PRIORITY_CHOICES = [
        ('high', 'High'),
        ('medium', 'Medium'),
        ('low', 'Low'),
    ]
    
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='medium')
    coordinator = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='coordinated_projects',
        limit_choices_to={'role__role': 'coordinator'}
    )
    assigned_field_officer = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_projects',
        limit_choices_to={'role__role': 'field_officer'}
    )
    assigned_client = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='client_projects',
        limit_choices_to={'role__role': 'client'}
    )
    assigned_agent = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='agent_projects',
        limit_choices_to={'role__role': 'agent'}
    )
    assigned_accessor = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='accessor_projects',
        limit_choices_to={'role__role': 'accessor'}
    )
    assigned_senior_valuer = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='senior_valuer_projects',
        limit_choices_to={'role__role': 'senior_valuer'}
    )
    has_agent = models.BooleanField(default=False, help_text='Whether this project requires an agent')
    client_info = models.JSONField(null=True, blank=True, help_text='Client information from project creation form')
    agent_info = models.JSONField(null=True, blank=True, help_text='Agent information from project creation form')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'projects'
        verbose_name = 'Project'
        verbose_name_plural = 'Projects'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.title} - {self.get_status_display()}"


class ProjectDocument(models.Model):
    """Documents attached to projects"""
    
    project = models.ForeignKey(
        Project,
        on_delete=models.CASCADE,
        related_name='documents'
    )
    file = models.FileField(upload_to='project_documents/%Y/%m/%d/')
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    uploaded_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='uploaded_documents'
    )
    assigned_to = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_documents',
        help_text='The assigned user this document is intended for'
    )
    uploaded_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'project_documents'
        verbose_name = 'Project Document'
        verbose_name_plural = 'Project Documents'
        ordering = ['-uploaded_at']
    
    def __str__(self):
        return f"{self.name} - {self.project.title}"

