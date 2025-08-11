import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/home_summary.dart';
import '../models/meter.dart';
import '../models/entry.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final http.Client _client;
  ApiService([http.Client? client]) : _client = client ?? http.Client();

  Future<List<Meter>> fetchMeters() async {
    final res = await _client.get(Uri.parse('$BASE_URL/home/$HOME_ID/meters'));
    if (res.statusCode != 200) throw Exception('Load meters failed');
    return (json.decode(res.body) as List)
        .map((e) => Meter.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<HomeSummary> fetchHomeSummary() async {
    final res = await _client.get(Uri.parse('$BASE_URL/home/$HOME_ID/summary'));
    if (res.statusCode != 200) throw Exception('Load summary failed');
    return HomeSummary.fromJson(json.decode(res.body));
  }

  Future<Map<String, dynamic>> fetchMonthlyData(
      String meterId, int year, int month) async {
    final uri = Uri.parse('$BASE_URL/home/$HOME_ID/meters/$meterId/data')
        .replace(queryParameters: {
      'year': year.toString(),
      'month': month.toString(),
    });
    final res = await _client.get(uri);
    if (res.statusCode != 200) throw Exception('Load month failed');
    final data = json.decode(res.body) as Map<String, dynamic>;
    return {
      'start_reading': (data['start_reading'] as num).toDouble(),
      'entries': (data['entries'] as List)
          .map((e) => Entry.fromJson(e as Map<String, dynamic>))
          .toList(),
    };
  }

  Future<void> postStartReading(
      String meterId, int year, int month, double reading) async {
    final res = await _client.post(
      Uri.parse('$BASE_URL/home/$HOME_ID/meters/$meterId/startReading'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'year': year, 'month': month, 'reading': reading}),
    );

    if (res.statusCode >= 300) {
      try {
        final errorData = json.decode(res.body);
        final errorMessage = errorData['detail'] ?? 'Set start failed';
        throw Exception(errorMessage);
      } catch (e) {
        // In case body is not valid JSON or detail field is missing
        throw Exception('Set start failed (${res.statusCode})');
      }
    }
  }


  Future<int> postEntry(
      String meterId, String dateIso, String name, double reading, String postingDate) async {
    final uri = Uri.parse(
        '$BASE_URL/home/$HOME_ID/meters/$meterId/entries');
    final body = json.encode({
      'date': dateIso,
      'name': name,
      'reading': reading,
      'posting_date': postingDate,
    });
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (res.statusCode >= 300) {
      try {
        final error = json.decode(res.body) as Map<String, dynamic>;
        throw Exception(error['detail'] ?? 'Post entry failed');
      } catch (_) {
        throw Exception('Post entry failed (\${res.statusCode})');
      }
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    return data['level'] as int? ?? 0;
  }


  Future<bool> hasStartReading(String meterId, int year, int month) async {
    final uri = Uri.parse(
        '$BASE_URL/home/$HOME_ID/meters/$meterId/hasStart'
    ).replace(queryParameters: {
      'year': year.toString(),
      'month': month.toString(),
    });
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to check start reading: ${res.statusCode}');
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    return body['has_start'] as bool;
  }

  /// Deletes a reading entry by ID.
  Future<void> deleteEntry(String meterId, String entryId) async {
    final uri = Uri.parse('$BASE_URL/home/$HOME_ID/meters/$meterId/entries/$entryId');
    final res = await _client.delete(uri);
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete entry (${res.statusCode}): ${res.body}');
    }
  }
  /// Toggles the `is_frozen` state on the server.
  Future<bool> toggleFreeze(String meterId, bool freeze) async {
    final uri = Uri.parse('$BASE_URL/home/$HOME_ID/meters/$meterId/freeze');
    final res = await _client.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'freeze': freeze}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to toggle freeze (${res.statusCode}): ${res.body}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    return data['is_frozen'] as bool;
  }

  Future<String> downloadMeterExcel(String meterId,String meterName, {int? year}) async {
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        await Permission.storage.request();
      }

      final currentYear = year ?? DateTime.now().year;
      final url = '$BASE_URL/home/$HOME_ID/meters/$meterId/export-excel?year=$currentYear&meter_name=$meterName';


      // Get downloads directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final filename = '${meterName}_${currentYear}_report.xlsx';
      final filePath = '${directory.path}/$filename';
      final _dio = Dio();
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(1);
            print('Download progress: $progress%');
          }
        },
      );


      return filePath;
    } catch (e) {
      throw Exception('Download failed: $e');
    }
  }


}