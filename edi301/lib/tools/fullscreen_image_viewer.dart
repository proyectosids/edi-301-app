import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatelessWidget {
  final ImageProvider imageProvider;
  final String heroTag;

  const FullScreenImageViewer({
    super.key,
    required this.imageProvider,
    required this.heroTag,
  });

  static void open(
    BuildContext context, {
    required ImageProvider imageProvider,
    required String heroTag,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageProvider: imageProvider,
          heroTag: heroTag,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image(image: imageProvider, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
