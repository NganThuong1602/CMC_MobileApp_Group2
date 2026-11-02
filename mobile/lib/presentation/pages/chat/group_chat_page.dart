import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/local/in_memory_database.dart';
import '../../../domain/entities/social_entities.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../blocs/auth/auth_cubit.dart';

/// Màn hình Group Chat Realtime (Socket.IO) giữa Khách hàng và toàn bộ Barber của quán.
class GroupChatPage extends StatefulWidget {
  final String roomId;
  const GroupChatPage({super.key, required this.roomId});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _msgCtrl = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  ChatRoomEntity? _room;

  @override
  void initState() {
    super.initState();
    _loadRoom();
    sl<SocketService>().joinChatRoom(widget.roomId);
    _socketSub = sl<SocketService>().onNewChatMessage.listen((_) {
      _loadRoom();
    });
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _loadRoom() {
    final db = sl<InMemoryDatabase>();
    final idx = db.chatRooms.indexWhere((r) => r.id == widget.roomId);
    if (idx != -1 && mounted) {
      setState(() => _room = db.chatRooms[idx]);
    }
  }

  Future<void> _send() async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null || _msgCtrl.text.trim().isEmpty) return;
    final text = _msgCtrl.text;
    _msgCtrl.clear();
    await sl<SocialRepository>().sendChatMessage(
      roomId: widget.roomId,
      senderId: user.id,
      content: text,
    );
    _loadRoom();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthCubit>().state.user;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Quay lại',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _room?.shopName ?? 'Group Chat Tư vấn',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const Text(
              'Socket.IO Realtime • Tất cả Barber trong quán',
              style: TextStyle(fontSize: 11.5, color: AppTheme.primaryGreen),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _room == null
                ? const Center(child: Text('Không tìm thấy phòng chat'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _room!.messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final m = _room!.messages[i];
                      final isMe = m.senderId == currentUser?.id;
                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 290),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? AppTheme.primaryGreen
                                : AppTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppTheme.softCardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text(
                                    '${m.senderName} (${m.senderRole.label})',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                ),
                              Text(
                                m.content,
                                style: TextStyle(
                                  color: isMe
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            color: AppTheme.surfaceWhite,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Nhập tin nhắn tư vấn kiểu tóc...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryGreen,
                    child: IconButton(
                      onPressed: _send,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

