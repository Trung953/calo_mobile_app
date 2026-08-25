import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_toast.dart';

class AvatarPickerWidget extends StatefulWidget {
  final String? currentAvatarUrl;
  final ApiClient apiClient;
  final Function(String newAvatarUrl)? onAvatarUploaded;

  const AvatarPickerWidget({
    super.key,
    this.currentAvatarUrl,
    required this.apiClient,
    this.onAvatarUploaded,
  });

  @override
  State<AvatarPickerWidget> createState() => _AvatarPickerWidgetState();
}

class _AvatarPickerWidgetState extends State<AvatarPickerWidget> {
  File? _pickedImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() {
        _pickedImage = File(picked.path);
        _isUploading = true;
      });

      // Gửi file lên Backend
      final res = await widget.apiClient.uploadFile(
        '${ApiEndpoints.profile}/avatar',
        _pickedImage!,
        'avatar',
      );

      final String? newUrl = res['data']?['avatarUrl'];
      if (newUrl != null && widget.onAvatarUploaded != null) {
        widget.onAvatarUploaded!(newUrl);
      }

      if (mounted) {
        AppToast.showSuccess(context, 'Đổi ảnh đại diện thành công!');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e, title: 'Không thể cập nhật ảnh');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showChoiceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thay đổi ảnh đại diện',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2DD4BF)),
                title: const Text('Chụp ảnh mới', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF2DD4BF)),
                title: const Text('Chọn ảnh từ thư viện', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? fullAvatarUrl;
    if (widget.currentAvatarUrl != null && widget.currentAvatarUrl!.isNotEmpty) {
      if (widget.currentAvatarUrl!.startsWith('http')) {
        fullAvatarUrl = widget.currentAvatarUrl;
      } else {
        final host = ApiEndpoints.baseUrl.replaceAll('/api/v1', '');
        fullAvatarUrl = '$host${widget.currentAvatarUrl}';
      }
    }

    return Center(
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2DD4BF), width: 2.5),
            ),
            child: ClipOval(
              child: _isUploading
                  ? Container(
                      color: const Color(0xFF1E293B),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2DD4BF),
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : _pickedImage != null
                      ? Image.file(_pickedImage!, fit: BoxFit.cover)
                      : (fullAvatarUrl != null)
                          ? Image.network(
                              fullAvatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white70,
                              ),
                            )
                          : Container(
                              color: const Color(0xFF1E293B),
                              child: const Icon(
                                Icons.person,
                                size: 50,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: _isUploading ? null : _showChoiceBottomSheet,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0F172A), width: 2),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}