import 'package:flutter/material.dart';

import 'ai_service_error.dart';
import 'api_client.dart';
import 'app_components.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _conversation = [];

  bool _sending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_sending) {
      return;
    }

    final message = _messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
      _errorMessage = null;

      _conversation.add({'role': 'user', 'content': message});

      _messageController.clear();
    });

    _scrollToBottom();

    try {
      final response = await widget.apiClient.sendChat(
        conversation: _conversation
            .map((item) => Map<String, String>.from(item))
            .toList(),
      );

      final assistantResponse = response['response'];

      if (assistantResponse is! String || assistantResponse.trim().isEmpty) {
        throw const ApiException('API returned an unexpected response.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _conversation.add({
          'role': 'assistant',
          'content': assistantResponse.trim(),
        });
      });

      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (_conversation.isNotEmpty &&
            _conversation.last['role'] == 'user' &&
            _conversation.last['content'] == message) {
          _conversation.removeLast();
        }

        _messageController.text = message;

        _messageController.selection = TextSelection.collapsed(
          offset: message.length,
        );

        _errorMessage = aiServiceErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        key: const ValueKey('recovery-companion-chat'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: AppPageHeader(
              title: 'Recovery Companion',
              subtitle: 'A place to reflect, get curious, and consider the next right thing.',
              icon: Icons.forum_outlined,
            ),
          ),

          Expanded(
            child: _conversation.isEmpty
                ? _EmptyChatState()
                : ListView.builder(
                    key: const ValueKey('chat-conversation'),
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: _conversation.length,
                    itemBuilder: (context, index) {
                      final message = _conversation[index];

                      final role = message['role'] ?? '';

                      final content = message['content'] ?? '';

                      return _ChatBubble(
                        role: role,
                        content: content,
                        index: index,
                      );
                    },
                  ),
          ),

          if (_sending)
            const LinearProgressIndicator(key: ValueKey('chat-sending')),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AppStatusMessage(
                title: 'Message not sent',
                message: _errorMessage!,
                icon: Icons.error_outline,
              ),
            ),

          _ChatComposer(
            controller: _messageController,
            sending: _sending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('chat-empty-state'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Icon(
                      Icons.chat_bubble_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'What is going on right now?',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Share what feels important, ask a recovery question, or talk through something you are trying to understand.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        const AppSectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This conversation is session-only and is not saved as chat history.',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        const AppSectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.people_outline),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recovery Companion can support reflection, but it does not replace your sponsor, fellowship, therapist, clergy, or Higher Power.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.role,
    required this.content,
    required this.index,
  });

  final String role;
  final String content;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';

    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: ValueKey('chat-message-$role-$index'),
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: isUser
              ? null
              : Border.all(color: colorScheme.outline.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.person_outline : Icons.forum_outlined,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  isUser ? 'You' : 'Recovery Companion',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(content),
          ],
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline
                .withValues(alpha: 0.22),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('chat-input'),
              controller: controller,
              enabled: !sending,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Message Recovery Companion',
                prefixIcon: Icon(Icons.chat_bubble_outline),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const ValueKey('chat-send'),
            onPressed: sending ? null : onSend,
            tooltip: 'Send message',
            icon: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
