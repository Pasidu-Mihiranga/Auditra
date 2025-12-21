from rest_framework import serializers
from django.contrib.auth.models import User
from .models import ChatMessage


class ChatMessageSerializer(serializers.ModelSerializer):
    """Serializer for chat messages"""
    sender_id = serializers.IntegerField(source='sender.id', read_only=True)
    sender_username = serializers.CharField(source='sender.username', read_only=True)
    sender_name = serializers.SerializerMethodField()
    recipient_id = serializers.IntegerField(source='recipient.id', read_only=True)
    recipient_username = serializers.CharField(source='recipient.username', read_only=True)
    recipient_name = serializers.SerializerMethodField()
    project_id = serializers.IntegerField(source='project.id', read_only=True, allow_null=True)
    project_title = serializers.CharField(source='project.title', read_only=True, allow_null=True)
    
    class Meta:
        model = ChatMessage
        fields = (
            'id', 'sender', 'sender_id', 'sender_username', 'sender_name',
            'recipient', 'recipient_id', 'recipient_username', 'recipient_name',
            'message', 'project', 'project_id', 'project_title',
            'created_at', 'read_at', 'is_read'
        )
        read_only_fields = ('sender', 'created_at', 'read_at', 'is_read')
    
    def get_sender_name(self, obj):
        if obj.sender.first_name or obj.sender.last_name:
            return f"{obj.sender.first_name} {obj.sender.last_name}".strip()
        return obj.sender.username
    
    def get_recipient_name(self, obj):
        if obj.recipient.first_name or obj.recipient.last_name:
            return f"{obj.recipient.first_name} {obj.recipient.last_name}".strip()
        return obj.recipient.username


class ChatMessageCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating chat messages"""
    
    class Meta:
        model = ChatMessage
        fields = ('recipient', 'message', 'project')
    
    def validate_recipient(self, value):
        """Ensure user is not sending message to themselves"""
        if value == self.context['request'].user:
            raise serializers.ValidationError("You cannot send a message to yourself.")
        return value


class ConversationSerializer(serializers.Serializer):
    """Serializer for conversation list"""
    user_id = serializers.IntegerField()
    username = serializers.CharField()
    name = serializers.CharField()
    last_message = serializers.CharField(allow_null=True)
    last_message_time = serializers.DateTimeField(allow_null=True)
    unread_count = serializers.IntegerField()
    project_id = serializers.IntegerField(allow_null=True)
    project_title = serializers.CharField(allow_null=True)



