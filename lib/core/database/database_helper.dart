import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../../models/hosting_record_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    const dbName = 'kolabpanel.db';
    final options = OpenDatabaseOptions(
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    if (kIsWeb) {
      return databaseFactoryFfiWeb.openDatabase(dbName, options: options);
    }

    final path = join(await getDatabasesPath(), dbName);
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Create admins table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS admins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');

    await _createHostingRecordsTable(db);
    await _seedAdmin(db);
    await _seedHostingRecords(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createHostingRecordsTable(db);
      await _seedHostingRecords(db);
    }
  }

  Future<void> _createHostingRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS hosting_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feature_key TEXT NOT NULL,
        title TEXT NOT NULL,
        primary_value TEXT NOT NULL,
        secondary_value TEXT NOT NULL,
        tertiary_value TEXT NOT NULL,
        description TEXT NOT NULL,
        status TEXT NOT NULL,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedAdmin(Database db) async {
    await db.rawInsert(
      "INSERT INTO admins (username, password) VALUES ('admin', 'admin123')",
    );
  }

  Future<void> _seedHostingRecords(Database db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) AS count FROM hosting_records'),
    );

    if ((count ?? 0) > 0) {
      return;
    }

    final now = DateTime.now().toIso8601String();
    final seedItems = <HostingRecord>[
      HostingRecord(
        featureKey: 'nginx_config',
        title: 'app.example.com',
        primaryValue: '80',
        secondaryValue: '/var/www/app',
        tertiaryValue: 'Laravel',
        description:
            'server {\n    listen 80;\n    server_name app.example.com;\n    root /var/www/app/public;\n    index index.html index.php;\n\n    location / {\n        try_files \$uri \$uri/ /index.php?\$query_string;\n    }\n}',
        status: 'available',
        isEnabled: false,
        createdAt: now,
        updatedAt: now,
      ),
      HostingRecord(
        featureKey: 'subdomain',
        title: 'dashboard.example.com',
        primaryValue: 'dashboard',
        secondaryValue: 'example.com',
        tertiaryValue: 'localhost:80',
        description: 'Arahkan dashboard.example.com ke localhost:80.',
        status: 'active',
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      HostingRecord(
        featureKey: 'domain',
        title: 'example.com',
        primaryValue: 'ada.ns.cloudflare.com',
        secondaryValue: 'nina.ns.cloudflare.com',
        tertiaryValue: 'Cloudflare',
        description: 'Nameserver untuk mengarahkan domain ke panel ini.',
        status: 'verified',
        isEnabled: false,
        createdAt: now,
        updatedAt: now,
      ),
      HostingRecord(
        featureKey: 'project',
        title: 'Landing Page',
        primaryValue: 'landing.example.com',
        secondaryValue: 'https://github.com/company/landing',
        tertiaryValue: 'Flutter',
        description: 'Project landing page yang dikelola dari panel hosting.',
        status: 'planning',
        isEnabled: false,
        createdAt: now,
        updatedAt: now,
      ),
      HostingRecord(
        featureKey: 'file_manager',
        title: 'public_html',
        primaryValue: '/public_html',
        secondaryValue: 'folder',
        tertiaryValue: 'Landing Page',
        description: 'Folder publik untuk deploy file static.',
        status: 'ready',
        isEnabled: false,
        createdAt: now,
        updatedAt: now,
      ),
      HostingRecord(
        featureKey: 'api_monitoring',
        title: 'Health Check API',
        primaryValue: 'https://api.example.com/health',
        secondaryValue: '5',
        tertiaryValue: '200',
        description: 'Monitor API setiap 5 detik dan simpan status terakhir.',
        status: 'healthy',
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      HostingRecord(
        featureKey: 'other_services',
        title: 'Backup Production DB',
        primaryValue: 'localhost/app_db',
        secondaryValue: 'MySQL',
        tertiaryValue: '3306',
        description:
            '{"schedule":"02:00","target":"/backups/database","retention":"Daily","notes":"Backup harian database produksi ke storage internal."}',
        status: 'ready',
        isEnabled: false,
        createdAt: now,
        updatedAt: now,
      ),
      HostingRecord(
        featureKey: 'server',
        title: 'Node-01',
        primaryValue: '192.168.1.10',
        secondaryValue: 'root',
        tertiaryValue: '22',
        description:
            '{"password":"admin123","notes":"Node utama aplikasi dan web server."}',
        status: 'online',
        isEnabled: false,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final batch = db.batch();
    for (final item in seedItems) {
      batch.insert('hosting_records', item.toMap());
    }
    await batch.commit(noResult: true);
  }

  // --- CRUD ADMIN ---
  Future<Map<String, dynamic>?> getAdminByCredentials(
    String username,
    String password,
  ) async {
    final db = await database;
    final res = await db.query(
      'admins',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    return res.isNotEmpty ? res.first : null;
  }

  // --- CRUD HOSTING RECORDS ---
  Future<int> insertHostingRecord(HostingRecord record) async {
    final db = await database;
    return await db.insert('hosting_records', record.toMap());
  }

  Future<List<HostingRecord>> getHostingRecords(
    String featureKey, {
    String query = '',
  }) async {
    final db = await database;
    final whereArgs = <dynamic>[featureKey];
    var whereClause = 'feature_key = ?';

    if (query.isNotEmpty) {
      whereClause +=
          ' AND (title LIKE ? OR primary_value LIKE ? OR secondary_value LIKE ? OR tertiary_value LIKE ? OR description LIKE ?)';
      final likeQuery = '%$query%';
      whereArgs.addAll([likeQuery, likeQuery, likeQuery, likeQuery, likeQuery]);
    }

    final rows = await db.query(
      'hosting_records',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC, created_at DESC',
    );

    return List.generate(
      rows.length,
      (index) => HostingRecord.fromMap(rows[index]),
    );
  }

  Future<int> updateHostingRecord(HostingRecord record) async {
    final db = await database;
    return await db.update(
      'hosting_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteHostingRecord(int id) async {
    final db = await database;
    return await db.delete('hosting_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countHostingRecords(String featureKey) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM hosting_records WHERE feature_key = ?',
      [featureKey],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getHostingCountsByFeature() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT feature_key, COUNT(*) AS count
      FROM hosting_records
      GROUP BY feature_key
    ''');
  }
}
