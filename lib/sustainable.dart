import 'package:flutter/material.dart';

class SustainablePage extends StatelessWidget {
  const SustainablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sustainable Farming',
          style: TextStyle(color: Colors.white), // Make text white
        ),
        backgroundColor: Colors.green.shade800,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // Make back button white if present
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SustainableFact(
            image: 'assets/crop.png',
            title: 'Crop Rotation',
            content:
                'Crop rotation involves growing different types of crops in the same area in sequential seasons. It helps improve soil health, reduce pest and weed pressure, and increase farm productivity.',
          ),
          const SizedBox(height: 24),
          _SustainableFact(
            image: 'assets/fertilizer.png',
            title: 'Use of Organic Fertilizers',
            content:
                'Organic fertilizers such as compost and manure enrich the soil with nutrients, improve soil structure, and promote beneficial microorganisms, reducing the need for chemical fertilizers.',
          ),
          const SizedBox(height: 24),
          _SustainableFact(
            image: 'assets/drip.png',
            title: 'Drip Irrigation',
            content:
                'Drip irrigation delivers water directly to the plant roots, minimizing water wastage and reducing weed growth. It is an efficient way to conserve water and ensure healthy crops.',
          ),
          const SizedBox(height: 24),
          _SustainableFact(
            image: 'assets/covercropping.png',
            title: 'Cover Cropping',
            content:
                'Cover crops are planted to cover the soil rather than for harvest. They prevent soil erosion, improve soil fertility, and suppress weeds, contributing to long-term soil health.',
          ),
        ],
      ),
    );
  }
}

class _SustainableFact extends StatelessWidget {
  final String image;
  final String title;
  final String content;

  const _SustainableFact({
    required this.image,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            image,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) => Container(
                  height: 160,
                  color: Colors.grey.shade300,
                  child: const Center(child: Icon(Icons.image_not_supported)),
                ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}
