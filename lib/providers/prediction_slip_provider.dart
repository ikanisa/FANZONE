import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_model.dart';
import 'package:uuid/uuid.dart';

enum PredictionType { matchResult, exactScore }

class PredictionSelection {
  const PredictionSelection({
    required this.id,
    required this.match,
    required this.type,
    required this.market,
    required this.selection,
    required this.title,
    required this.subtitle,
    this.multiplier,
  });

  final String id;
  final MatchModel match;
  final PredictionType type;
  final String market;
  final String selection; // '1', 'X', '2', or '2-1'
  final String title; // e.g. 'Arsenal to Win'
  final String subtitle; // e.g. 'Arsenal vs Chelsea • Match Result'
  final double? multiplier;

  PredictionSelection copyWith({
    String? id,
    MatchModel? match,
    PredictionType? type,
    String? market,
    String? selection,
    String? title,
    String? subtitle,
    double? multiplier,
  }) {
    return PredictionSelection(
      id: id ?? this.id,
      match: match ?? this.match,
      type: type ?? this.type,
      market: market ?? this.market,
      selection: selection ?? this.selection,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      multiplier: multiplier ?? this.multiplier,
    );
  }

  int projectedEarnForStake(int stake) {
    if (stake <= 0 || multiplier == null) return 0;
    return (stake * multiplier!).round();
  }
}

class PredictionSlipNotifier extends Notifier<List<PredictionSelection>> {
  @override
  List<PredictionSelection> build() => [];

  void toggleMatchResult(MatchModel match, String pick, {double? multiplier}) {
    // If exact same pick exists for this match, remove it (toggle off)
    // If different pick exists for this match, replace it (cannot pick 1 and X simultaneously for same market)
    final existingIndex = state.indexWhere(
      (p) => p.match.id == match.id && p.type == PredictionType.matchResult,
    );

    if (existingIndex != -1) {
      if (state[existingIndex].selection == pick) {
        // Toggle off
        final newState = List<PredictionSelection>.from(state)
          ..removeAt(existingIndex);
        state = newState;
        return;
      } else {
        // Replace
        final newState = List<PredictionSelection>.from(state);
        newState[existingIndex] = _createSelection(
          match,
          PredictionType.matchResult,
          pick,
          multiplier: multiplier,
        );
        state = newState;
        return;
      }
    }

    // Add new
    state = [
      ...state,
      _createSelection(
        match,
        PredictionType.matchResult,
        pick,
        multiplier: multiplier,
      ),
    ];
  }

  void toggleExactScore(
    MatchModel match,
    int homeScore,
    int awayScore, {
    double? multiplier,
  }) {
    final pick = '$homeScore-$awayScore';
    final existingIndex = state.indexWhere(
      (p) => p.match.id == match.id && p.type == PredictionType.exactScore,
    );

    if (existingIndex != -1) {
      if (state[existingIndex].selection == pick) {
        final newState = List<PredictionSelection>.from(state)
          ..removeAt(existingIndex);
        state = newState;
        return;
      } else {
        final newState = List<PredictionSelection>.from(state);
        newState[existingIndex] = _createSelection(
          match,
          PredictionType.exactScore,
          pick,
          multiplier: multiplier,
        );
        state = newState;
        return;
      }
    }

    state = [
      ...state,
      _createSelection(
        match,
        PredictionType.exactScore,
        pick,
        multiplier: multiplier,
      ),
    ];
  }

  void removeSelection(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void clear() {
    state = [];
  }

  PredictionSelection _createSelection(
    MatchModel match,
    PredictionType type,
    String pick, {
    double? multiplier,
  }) {
    String title = '';
    String subtitle = '${match.homeTeam} vs ${match.awayTeam}';
    String market = '';

    if (type == PredictionType.matchResult) {
      if (pick == '1') {
        title = '${match.homeTeam} to Win';
      } else if (pick == 'X') {
        title = 'Draw';
      } else if (pick == '2') {
        title = '${match.awayTeam} to Win';
      }
      subtitle += ' • Match Result';
      market = 'match_result';
    } else {
      title = 'Exact Score: $pick';
      subtitle += ' • Correct Score';
      market = 'exact_score';
    }

    return PredictionSelection(
      id: const Uuid().v4(),
      match: match,
      type: type,
      market: market,
      selection: pick,
      title: title,
      subtitle: subtitle,
      multiplier: multiplier,
    );
  }
}

final predictionSlipProvider =
    NotifierProvider<PredictionSlipNotifier, List<PredictionSelection>>(() {
      return PredictionSlipNotifier();
    });
