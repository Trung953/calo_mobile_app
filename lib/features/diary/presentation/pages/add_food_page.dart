import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/utils/app_toast.dart';
import '../../data/models/diary_entry_model.dart';
import '../../data/models/food_model.dart';
import '../../data/repositories/diary_repository.dart';
import '../widgets/food_log_dialog.dart';
import 'create_custom_food_page.dart';

class AddFoodPage extends StatefulWidget {
  final DiaryRepository repository;
  final DateTime selectedDate;
  final String defaultMealType;

  const AddFoodPage({
    super.key,
    required this.repository,
    required this.selectedDate,
    this.defaultMealType = 'BREAKFAST',
  });

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabController;

  List<FoodModel> _searchResults = [];
  List<FoodModel> _favoriteResults = [];
  Set<String> _favoriteIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        _fetchFavorites();
      }
    });
    _search('');
    _fetchFavorites();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFavorites() async {
    try {
      final res = await widget.repository.apiClient.get(ApiEndpoints.favorites);
      final List list = res['data'] ?? [];
      if (mounted) {
        setState(() {
          _favoriteResults = list.map((e) => FoodModel.fromJson(e)).toList();
          _favoriteIds = _favoriteResults.map((e) => e.id).toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite(String foodId) async {
    try {
      final res = await widget.repository.apiClient.post('${ApiEndpoints.favorites}/toggle', {
        'foodId': foodId,
      });
      final bool isFav = res['data']?['isFavorite'] ?? false;
      if (!mounted) return;
      setState(() {
        if (isFav) {
          _favoriteIds.add(foodId);
        } else {
          _favoriteIds.remove(foodId);
          _favoriteResults.removeWhere((item) => item.id == foodId);
        }
      });
      AppToast.showSuccess(
        context,
        isFav ? 'Đã thêm vào danh sách yêu thích' : 'Đã xóa khỏi danh sách yêu thích',
      );
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e, title: 'Thao tác không thành công');
      }
    }
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await widget.repository.searchFoods(query);
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e, title: 'Không thể tải món ăn');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFoodLogDialog(FoodModel food) {
    showDialog(
      context: context,
      builder: (ctx) => FoodLogDialog(
        food: food,
        initialMealType: widget.defaultMealType,
        selectedDate: widget.selectedDate,
        onSave: (DiaryEntryModel entry) async {
          await widget.repository.addDiaryEntry(entry);
        },
      ),
    ).then((saved) {
      if (saved == true && mounted) {
        AppToast.showSuccess(context, 'Đã ghi nhận "${food.name}" vào nhật ký');
        Navigator.pop(context, true);
      }
    });
  }

  Future<void> _openCameraFlow() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCustomFoodPage(
          repository: widget.repository,
          selectedDate: widget.selectedDate,
          defaultMealType: widget.defaultMealType,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final Color scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
        final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        final Color inputFill = isDark ? const Color(0xFF1E293B) : Colors.white;

        return Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: scaffoldBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Chọn Món Ăn',
              style: GoogleFonts.plusJakartaSans(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            // ĐÃ XÓA TOÀN BỘ NÚT Ở GÓC PHẢI HEADER
            actions: const [],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: subColor,
                  labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13.5),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  padding: const EdgeInsets.all(3),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant_menu_rounded, size: 17),
                          SizedBox(width: 8),
                          Text('Tất cả món'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_rounded, size: 17),
                          SizedBox(width: 8),
                          Text('Món yêu thích'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: TẤT CẢ MÓN & TÌM KIẾM
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: inputFill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.w600, fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm món ăn (cơm, phở, ức gà...)',
                          hintStyle: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 13.5),
                          prefixIcon: Icon(Icons.search_rounded, color: subColor, size: 22),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchCtrl.text.isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.clear_rounded, color: subColor, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _search('');
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF10B981)),
                                tooltip: 'Quét calo từ ảnh',
                                onPressed: _openCameraFlow,
                              ),
                            ],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (val) => _search(val),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                        : _searchResults.isEmpty
                            ? _buildEmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'Không tìm thấy món ăn',
                                subtitle: 'Thử tìm từ khóa khác hoặc bấm nút chụp ảnh để AI nhận diện món mới!',
                                subColor: subColor,
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) => _buildFoodCard(
                                  food: _searchResults[index],
                                  cardBg: cardBg,
                                  textColor: textColor,
                                  subColor: subColor,
                                  borderColor: borderColor,
                                  isDark: isDark,
                                ),
                              ),
                  ),
                ],
              ),

              // TAB 2: MÓN YÊU THÍCH
              _favoriteResults.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.star_border_rounded,
                      title: 'Chưa có món yêu thích',
                      subtitle: 'Nhấn vào biểu tượng ngôi sao ở các món ăn thường dùng để truy cập nhanh tại đây!',
                      subColor: subColor,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: _favoriteResults.length,
                      itemBuilder: (context, index) => _buildFoodCard(
                        food: _favoriteResults[index],
                        cardBg: cardBg,
                        textColor: textColor,
                        subColor: subColor,
                        borderColor: borderColor,
                        isDark: isDark,
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFoodCard({
    required FoodModel food,
    required Color cardBg,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
    required bool isDark,
  }) {
    final bool isFav = _favoriteIds.contains(food.id);

    // Format gọn 1 chữ số thập phân
    String formatMacro(double val) => val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openFoodLogDialog(food),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            food.name,
                            style: GoogleFonts.plusJakartaSans(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (food.isCustom) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Tự tạo',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${food.calories} kcal',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          '/ 100g',
                          style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 11.5),
                        ),
                        const SizedBox(width: 4),
                        _buildMacroBadge('C', formatMacro(food.carbsG), const Color(0xFFFBBF24)),
                        _buildMacroBadge('P', formatMacro(food.proteinG), const Color(0xFFF87171)),
                        _buildMacroBadge('F', formatMacro(food.fatG), const Color(0xFF34D399)),
                        _buildMacroBadge('X', formatMacro(food.fiberG), const Color(0xFFA855F7)), // Thêm chất xơ
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFav ? const Color(0xFFFBBF24) : subColor,
                  size: 24,
                ),
                onPressed: () => _toggleFavorite(food.id),
              ),
              GestureDetector(
                onTap: () => _openFoodLogDialog(food),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroBadge(String label, String value, Color color) {
    return Text(
      '$label:$value',
      style: GoogleFonts.plusJakartaSans(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color subColor,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: subColor.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: subColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: subColor.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}