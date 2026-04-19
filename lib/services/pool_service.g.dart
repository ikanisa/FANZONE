// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pool_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$poolDetailHash() => r'25c3309c04161be80205c2ba5ac64e4373ea74ca';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Provider for a single pool by ID — used by PoolDetailScreen.
///
/// Copied from [poolDetail].
@ProviderFor(poolDetail)
const poolDetailProvider = PoolDetailFamily();

/// Provider for a single pool by ID — used by PoolDetailScreen.
///
/// Copied from [poolDetail].
class PoolDetailFamily extends Family<AsyncValue<ScorePool?>> {
  /// Provider for a single pool by ID — used by PoolDetailScreen.
  ///
  /// Copied from [poolDetail].
  const PoolDetailFamily();

  /// Provider for a single pool by ID — used by PoolDetailScreen.
  ///
  /// Copied from [poolDetail].
  PoolDetailProvider call(String id) {
    return PoolDetailProvider(id);
  }

  @override
  PoolDetailProvider getProviderOverride(
    covariant PoolDetailProvider provider,
  ) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'poolDetailProvider';
}

/// Provider for a single pool by ID — used by PoolDetailScreen.
///
/// Copied from [poolDetail].
class PoolDetailProvider extends AutoDisposeFutureProvider<ScorePool?> {
  /// Provider for a single pool by ID — used by PoolDetailScreen.
  ///
  /// Copied from [poolDetail].
  PoolDetailProvider(String id)
    : this._internal(
        (ref) => poolDetail(ref as PoolDetailRef, id),
        from: poolDetailProvider,
        name: r'poolDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$poolDetailHash,
        dependencies: PoolDetailFamily._dependencies,
        allTransitiveDependencies: PoolDetailFamily._allTransitiveDependencies,
        id: id,
      );

  PoolDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<ScorePool?> Function(PoolDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PoolDetailProvider._internal(
        (ref) => create(ref as PoolDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ScorePool?> createElement() {
    return _PoolDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PoolDetailProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PoolDetailRef on AutoDisposeFutureProviderRef<ScorePool?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _PoolDetailProviderElement
    extends AutoDisposeFutureProviderElement<ScorePool?>
    with PoolDetailRef {
  _PoolDetailProviderElement(super.provider);

  @override
  String get id => (origin as PoolDetailProvider).id;
}

String _$poolServiceHash() => r'918652b462276dcf6d524e8bb7ead4d89d5566ae';

/// See also [PoolService].
@ProviderFor(PoolService)
final poolServiceProvider =
    AutoDisposeAsyncNotifierProvider<PoolService, List<ScorePool>>.internal(
      PoolService.new,
      name: r'poolServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$poolServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PoolService = AutoDisposeAsyncNotifier<List<ScorePool>>;
String _$myEntriesHash() => r'ec114d79b643dd120888658c7da3f4a11698e4f4';

/// See also [MyEntries].
@ProviderFor(MyEntries)
final myEntriesProvider =
    AutoDisposeAsyncNotifierProvider<MyEntries, List<PoolEntry>>.internal(
      MyEntries.new,
      name: r'myEntriesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$myEntriesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MyEntries = AutoDisposeAsyncNotifier<List<PoolEntry>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
