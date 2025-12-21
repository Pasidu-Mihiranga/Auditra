from datetime import datetime
from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.pagination import PageNumberPagination
from django.contrib.auth.models import User
from django.db.models import Q, Max, OuterRef, Subquery
from django.utils import timezone
from .models import ChatMessage
from .serializers import (
    ChatMessageSerializer,
    ChatMessageCreateSerializer,
    ConversationSerializer
)


class ChatMessagePagination(PageNumberPagination):
    """Pagination for chat messages"""
    page_size = 50
    page_size_query_param = 'page_size'
    max_page_size = 100


class ChatMessageListCreateView(generics.ListCreateAPIView):
    """List messages with a specific user or create a new message"""
    permission_classes = [IsAuthenticated]
    pagination_class = ChatMessagePagination
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return ChatMessageCreateSerializer
        return ChatMessageSerializer
    
    def get_queryset(self):
        user = self.request.user
        recipient_id = self.request.query_params.get('recipient')
        project_id = self.request.query_params.get('project')
        
        # Build query for messages between current user and recipient
        if recipient_id:
            try:
                recipient = User.objects.get(id=recipient_id)
                # Get messages where current user is sender or recipient
                queryset = ChatMessage.objects.filter(
                    Q(sender=user, recipient=recipient) |
                    Q(sender=recipient, recipient=user)
                )
                
                # Filter by project if provided
                if project_id:
                    queryset = queryset.filter(project_id=project_id)
                
                # Mark messages as read when viewing
                ChatMessage.objects.filter(
                    sender=recipient,
                    recipient=user,
                    is_read=False
                ).update(is_read=True, read_at=timezone.now())
                
                return queryset.order_by('created_at')
            except User.DoesNotExist:
                return ChatMessage.objects.none()
        
        # If no recipient specified, return empty queryset
        return ChatMessage.objects.none()
    
    def perform_create(self, serializer):
        """Set sender to current user"""
        serializer.save(sender=self.request.user)
    
    def create(self, request, *args, **kwargs):
        """Create a new message"""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        
        # Return the created message with full details
        message_serializer = ChatMessageSerializer(
            serializer.instance,
            context={'request': request}
        )
        
        return Response(
            message_serializer.data,
            status=status.HTTP_201_CREATED
        )


class ConversationListView(APIView):
    """Get list of conversations for the current user"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        user = request.user
        
        # Get all unique users the current user has conversed with
        # (either as sender or recipient)
        sent_to = ChatMessage.objects.filter(sender=user).values('recipient').distinct()
        received_from = ChatMessage.objects.filter(recipient=user).values('sender').distinct()
        
        # Combine and get unique user IDs
        user_ids = set()
        for item in sent_to:
            user_ids.add(item['recipient'])
        for item in received_from:
            user_ids.add(item['sender'])
        
        conversations = []
        
        for user_id in user_ids:
            try:
                other_user = User.objects.get(id=user_id)
                
                # Get last message between users
                last_message = ChatMessage.objects.filter(
                    Q(sender=user, recipient=other_user) |
                    Q(sender=other_user, recipient=user)
                ).order_by('-created_at').first()
                
                # Count unread messages
                unread_count = ChatMessage.objects.filter(
                    sender=other_user,
                    recipient=user,
                    is_read=False
                ).count()
                
                # Get project info if last message has a project
                project_id = None
                project_title = None
                if last_message and last_message.project:
                    project_id = last_message.project.id
                    project_title = last_message.project.title
                
                # Get user's full name
                if other_user.first_name or other_user.last_name:
                    name = f"{other_user.first_name} {other_user.last_name}".strip()
                else:
                    name = other_user.username
                
                conversations.append({
                    'user_id': other_user.id,
                    'username': other_user.username,
                    'name': name,
                    'last_message': last_message.message if last_message else None,
                    'last_message_time': last_message.created_at if last_message else None,
                    'unread_count': unread_count,
                    'project_id': project_id,
                    'project_title': project_title,
                })
            except User.DoesNotExist:
                continue
        
        # Sort by last message time (most recent first)
        conversations.sort(
            key=lambda x: x['last_message_time'] or datetime.min.replace(tzinfo=timezone.utc),
            reverse=True
        )
        
        serializer = ConversationSerializer(conversations, many=True)
        return Response({
            'results': serializer.data,
            'count': len(conversations)
        }, status=status.HTTP_200_OK)


class UnreadMessageCountView(APIView):
    """Get count of unread messages for the current user"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        user = request.user
        unread_count = ChatMessage.objects.filter(
            recipient=user,
            is_read=False
        ).count()
        
        return Response({
            'unread_count': unread_count
        }, status=status.HTTP_200_OK)
