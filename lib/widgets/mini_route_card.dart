import 'package:flutter/material.dart';

Widget miniRouteCard({required String title, String? subtitle}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          if (subtitle != null) Text(subtitle!, style: TextStyle(color: Colors.grey[700])),
        ]),
        Column(children: [Text('2.8 km', style: TextStyle(fontWeight: FontWeight.bold)), Text('40 min')]),
      ],
    ),
  );
}
