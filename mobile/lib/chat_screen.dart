import 'package:flutter/material.dart';

import 'api_client.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<ChatScreen> createState() {
    return _ChatScreenState();
  }
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
        _conversation.add({'role': 'assistant', 'content': assistantResponse});
      });

      _scrollToBottom();
    } catch (_) {
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

        _errorMessage = 'Unable to send your message. Please try again.';
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
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          if (_conversation.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Recovery Companion Chat',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Share what is going on, ask a recovery '
                        'question, or work through what feels '
                        'important right now.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This conversation is session-only and '
                        'is not saved as chat history.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _conversation.length,
                itemBuilder: (context, index) {
                  final message = _conversation[index];

                  final role = message['role'] ?? '';

                  final content = message['content'] ?? '';

                  final isUser = role == 'user';

                  return Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      key: ValueKey('chat-message-$role-$index'),
                      constraints: const BoxConstraints(maxWidth: 520),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUser ? 'You' : 'Recovery Companion',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(content),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          if (_sending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(),
            ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _errorMessage!,
                key: const ValueKey('chat-error'),
                style: TextStyle(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('chat-input'),
                    controller: _messageController,
                    enabled: !_sending,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Message Recovery Companion',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const ValueKey('chat-send'),
                  onPressed: _sending ? null : _sendMessage,
                  tooltip: 'Send message',
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
