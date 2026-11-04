import 'package:equatable/equatable.dart';

import '../../domain/entities/catalog_category.dart';
import '../../domain/failures/catalog_failure.dart';

enum CatalogStatus { initial, loading, success, error }

/// SOLID (SRP): estado del menú — las pantallas derivan vistas; el
/// refresh silencioso mantiene `categories` mientras re-pide (status no
/// vuelve a loading si ya hay datos).
class CatalogState extends Equatable {
  const CatalogState({
    required this.status,
    required this.categories,
    this.failure,
  });

  const CatalogState.initial()
    : status = CatalogStatus.initial,
      categories = const [],
      failure = null;

  final CatalogStatus status;
  final List<CatalogCategory> categories;
  final CatalogFailure? failure;

  @override
  List<Object?> get props => [status, categories, failure];
}
