import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// FANZONE ships with a single supported appearance.
final themeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.dark);
