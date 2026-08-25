import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_toast.dart';

class WeightTrackerPage extends StatefulWidget {
  final ApiClient apiClient;

  const WeightTrackerPage({super.key, required this.apiClient});

  @override
  State<WeightTrackerPage> createState() => _WeightTrackerPageState();
}

class _WeightTrackerPageState extends State<WeightTrackerPage> {
  bool _isLoading = true;
  double _currentWeight = 0.0;
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchWeights();
  }

  Future<void> _fetchWeights() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiClient.get(ApiEndpoints.weights);
      final data = res['data'];
      if (data != null && mounted) {
        setState(() {
          _currentWeight = (data['currentWeight'] as num?)?.toDouble() ?? 0.0;
          _logs = data['logs'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e, title: 'Không thể tải lịch sử cân nặng');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddWeightDialog() {
    final weightCtrl = TextEditingController(
      text: _currentWeight > 0 ? _currentWeight.toStringAsFixed(1) : '65.0',
    );
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ghi nhận Cân nặng', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cân nặng (kg)',
                  suffixText: 'kg',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ngày ghi nhận'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                trailing: const Icon(Icons.calendar_today, color: Colors.teal),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                final weight = double.tryParse(weightCtrl.text);
                if (weight == null || weight <= 0) {
                  AppToast.showError(context, 'Vui lòng nhập số cân nặng hợp lệ', title: 'Thông số không hợp lệ');
                  return;
                }

                final navigator = Navigator.of(ctx);
                final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                
                try {
                  await widget.apiClient.post(ApiEndpoints.weights, {
                    'weightKg': weight,
                    'date': dateStr,
                  });

                  if (!mounted) return;
                  navigator.pop();
                  AppToast.showSuccess(context, 'Đã ghi nhận cân nặng: ${weight.toStringAsFixed(1)} kg');
                  _fetchWeights();
                } catch (e) {
                  if (!mounted) return;
                  AppToast.showError(context, e, title: 'Không thể lưu cân nặng');
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLog(String id) async {
    try {
      await widget.apiClient.delete('${ApiEndpoints.weights}/$id');
      if (mounted) {
        AppToast.showSuccess(context, 'Đã xóa bản ghi cân nặng');
      }
      _fetchWeights();
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e, title: 'Không thể xóa bản ghi');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    return RefreshIndicator(
      onRefresh: _fetchWeights,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.teal.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  const Text('Cân nặng hiện tại', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _currentWeight.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const SizedBox(width: 6),
                      const Text('kg', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showAddWeightDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ghi cân nặng hôm nay'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Lịch Sử Cân Nặng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('Chưa có lịch sử ghi cân nặng.')),
            )
          else
            ..._logs.map((log) {
              final date = DateTime.parse(log['date']);
              final weight = (log['weightKg'] as num).toDouble();

              return Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.monitor_weight_outlined, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    '${weight.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(DateFormat('EEEE, dd/MM/yyyy').format(date)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => _deleteLog(log['id']),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}