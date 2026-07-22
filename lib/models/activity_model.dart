import 'package:flutter/material.dart';

/// 活动大类：每个大类持有一个固定的颜色，其下所有活动共享该颜色。
class ActivityCategory {
  String name;
  int colorValue; // Color.value

  ActivityCategory({required this.name, required this.colorValue});

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() => {'name': name, 'colorValue': colorValue};

  factory ActivityCategory.fromMap(Map<String, dynamic> m) => ActivityCategory(
        name: m['name'] as String,
        colorValue: m['colorValue'] as int,
      );

  ActivityCategory copyWith({String? name, int? colorValue}) => ActivityCategory(
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
      );
}

/// 活动项目（记录页可计时项）：名称 + 图标 + 所属大类。
/// 颜色由其所属大类的颜色决定（同一大类同色）。
class ActivityType {
  String name;
  int iconCodePoint; // IconData.codePoint
  String categoryName; // 所属大类的 name

  ActivityType({
    required this.name,
    required this.iconCodePoint,
    required this.categoryName,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'iconCodePoint': iconCodePoint,
        'categoryName': categoryName,
      };

  factory ActivityType.fromMap(Map<String, dynamic> m) => ActivityType(
        name: m['name'] as String,
        iconCodePoint: m['iconCodePoint'] as int,
        categoryName: m['categoryName'] as String,
      );

  ActivityType copyWith({
    String? name,
    int? iconCodePoint,
    String? categoryName,
  }) =>
      ActivityType(
        name: name ?? this.name,
        iconCodePoint: iconCodePoint ?? this.iconCodePoint,
        categoryName: categoryName ?? this.categoryName,
      );
}
