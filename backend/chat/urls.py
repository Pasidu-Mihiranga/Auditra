from django.urls import path
from .views import (
    ChatMessageListCreateView,
    ConversationListView,
    UnreadMessageCountView
)

urlpatterns = [
    path('messages/', ChatMessageListCreateView.as_view(), name='chat-messages'),
    path('conversations/', ConversationListView.as_view(), name='chat-conversations'),
    path('unread-count/', UnreadMessageCountView.as_view(), name='chat-unread-count'),
]



