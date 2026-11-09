import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/local/in_memory_database.dart';
import '../../../data/datasources/remote/remote_api_datasource.dart';
import '../../../domain/entities/social_entities.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../blocs/auth/auth_cubit.dart';

/// Màn hình Chat Realtime (Socket.IO) trực tiếp giữa Khách hàng và Chủ quán (Manager).
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
  String? _msgError;

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

  Future<void> _loadRoom() async {
    final db = sl<InMemoryDatabase>();
    final idx = db.chatRooms.indexWhere((r) => r.id == widget.roomId);
    if (idx != -1 && mounted) {
      setState(() => _room = db.chatRooms[idx]);
    }
    try {
      final msgMaps =
          await sl<RemoteApiDataSource>().getRoomMessages(widget.roomId);
      final msgs = msgMaps.map((m) {
        return ChatMessageEntity(
          id: (m['id'] ?? '').toString(),
          roomId: widget.roomId,
          senderId: (m['senderId'] ?? '').toString(),
          senderName: (m['senderName'] ?? 'Thành viên').toString(),
          senderRole: UserRole.fromApi(m['senderRole']?.toString()),
          content: (m['content'] ?? '').toString(),
          createdAt:
              DateTime.tryParse((m['createdAt'] ?? '').toString()) ??
                  DateTime.now(),
        );
      }).toList();
      final currentIdx = db.chatRooms.indexWhere((r) => r.id == widget.roomId);
      final updatedRoom = currentIdx != -1
          ? ChatRoomEntity(
              id: db.chatRooms[currentIdx].id,
              shopId: db.chatRooms[currentIdx].shopId,
              shopName: db.chatRooms[currentIdx].shopName,
              customerId: db.chatRooms[currentIdx].customerId,
              customerName: db.chatRooms[currentIdx].customerName,
              messages: msgs,
            )
          : ChatRoomEntity(
              id: widget.roomId,
              shopId: '',
              shopName: 'Tư vấn khách hàng',
              customerId: '',
              customerName: 'Khách hàng',
              messages: msgs,
            );
      if (currentIdx != -1) {
        db.chatRooms[currentIdx] = updatedRoom;
      } else {
        db.chatRooms.add(updatedRoom);
      }
      if (mounted) {
        setState(() => _room = updatedRoom);
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    if (_msgCtrl.text.trim().isEmpty) {
      setState(() => _msgError = 'Vui lòng nhập nội dung tin nhắn trước khi gửi');
      return;
    }
    setState(() => _msgError = null);
    final text = _msgCtrl.text.trim();
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
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;
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
              _room?.shopName ?? 'Chat với quán',
              style: tt.sectionTitle,
            ),
            Text(
              'Trò chuyện trực tiếp với Chủ quán (Quản lý)',
              style: tt.badgePrimary,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _room == null
                ? Center(
                    child: Text(
                      'Không tìm thấy phòng chat',
                      style: tt.bodyMuted,
                    ),
                  )
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
                            color: isMe ? cs.primary : cs.surface,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: appColors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text(
                                    '${m.senderName} (${m.senderRole.label})',
                                    style: tt.badgePrimary,
                                  ),
                                ),
                              Text(
                                m.content,
                                style: isMe
                                    ? tt.bodyOnPrimary
                                    : tt.bodyRegular,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            color: cs.surface,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      onChanged: (_) {
                        if (_msgError != null) {
                          setState(() => _msgError = null);
                        }
                      },
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn gửi tới quán...',
                        errorText: _msgError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: cs.primary,
                    child: IconButton(
                      onPressed: _send,
                      icon: Icon(
                        Icons.send_rounded,
                        color: cs.onPrimary,
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
