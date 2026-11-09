import 'package:flutter/material.dart';
import '../../data/models/product.dart';
import '../../data/models/upgrade.dart';

/// Ikon bergambar untuk menu (espresso, americano, ..., donat, croissant, cheesecake).
class ProductIcon extends StatelessWidget {
  const ProductIcon(this.product, {super.key, this.size = 32, this.dim = false});
  final Product product;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: dim ? 0.4 : 1,
        child: Image.asset(product.iconAsset, width: size, height: size, fit: BoxFit.contain, filterQuality: FilterQuality.medium, gaplessPlayback: true),
      );
}

/// Ikon bahan stok: biji kopi, susu, tepung.
class StockIcon extends StatelessWidget {
  const StockIcon(this.item, {super.key, this.size = 40});
  final StockItem item;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset('assets/icons/${item.name}.png',
      width: size, height: size, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
}
