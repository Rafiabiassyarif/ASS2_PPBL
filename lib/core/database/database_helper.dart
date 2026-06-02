import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../../models/hosting_record_model.dart';
import '../../models/domain_model.dart';
import '../../models/user_model.dart';
import '../../models/package_model.dart';
import '../../models/ticket_model.dart';

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
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Create admins table
    await db.execute('''
      CREATE TABLE admins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');

    // 2. Create packages table
    await db.execute('''
      CREATE TABLE packages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_paket TEXT NOT NULL,
        harga INTEGER NOT NULL,
        kuota_disk INTEGER NOT NULL,
        max_domain INTEGER NOT NULL,
        deskripsi TEXT
      )
    ''');

    // 3. Create users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        paket_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        tanggal_daftar TEXT NOT NULL,
        FOREIGN KEY (paket_id) REFERENCES packages (id) ON DELETE RESTRICT
      )
    ''');

    // 4. Create domains table
    await db.execute('''
      CREATE TABLE domains (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_domain TEXT NOT NULL,
        client_id INTEGER NOT NULL,
        tanggal_daftar TEXT NOT NULL,
        tanggal_expired TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 5. Create tickets table
    await db.execute('''
      CREATE TABLE tickets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        subjek TEXT NOT NULL,
        pesan TEXT NOT NULL,
        status TEXT NOT NULL,
        prioritas TEXT NOT NULL,
        tanggal_buat TEXT NOT NULL,
        tanggal_update TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await _createHostingRecordsTable(db);

    // Seed mock data
    await _seedData(db);
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
      CREATE TABLE hosting_records (
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

  Future<void> _seedData(Database db) async {
    // Admin
    await db.rawInsert(
      "INSERT INTO admins (username, password) VALUES ('admin', 'admin123')",
    );

    // Packages
    await db.rawInsert(
      "INSERT INTO packages (id, nama_paket, harga, kuota_disk, max_domain, deskripsi) VALUES (1, 'Starter Pack', 50000, 10, 2, 'Paket hemat untuk website personal')",
    );
    await db.rawInsert(
      "INSERT INTO packages (id, nama_paket, harga, kuota_disk, max_domain, deskripsi) VALUES (2, 'Business Pro', 150000, 50, 10, 'Paket lengkap untuk bisnis menengah')",
    );
    await db.rawInsert(
      "INSERT INTO packages (id, nama_paket, harga, kuota_disk, max_domain, deskripsi) VALUES (3, 'Enterprise Ultimate', 450000, 200, 50, 'Performa maksimal untuk corporate web')",
    );

    // Users
    await db.rawInsert(
      "INSERT INTO users (id, nama, email, paket_id, status, tanggal_daftar) VALUES (1, 'Budi Santoso', 'budi@gmail.com', 2, 'aktif', '2026-01-15')",
    );
    await db.rawInsert(
      "INSERT INTO users (id, nama, email, paket_id, status, tanggal_daftar) VALUES (2, 'Dewi Lestari', 'dewi@yahoo.com', 1, 'aktif', '2026-02-10')",
    );
    await db.rawInsert(
      "INSERT INTO users (id, nama, email, paket_id, status, tanggal_daftar) VALUES (3, 'Rian Hidayat', 'rian@outlook.com', 3, 'suspended', '2026-03-01')",
    );
    await db.rawInsert(
      "INSERT INTO users (id, nama, email, paket_id, status, tanggal_daftar) VALUES (4, 'Siti Aminah', 'siti@gmail.com', 2, 'aktif', '2026-04-05')",
    );

    // Domains
    await db.rawInsert(
      "INSERT INTO domains (nama_domain, client_id, tanggal_daftar, tanggal_expired, status) VALUES ('budiprakoso.com', 1, '2026-01-15', '2027-01-15', 'aktif')",
    );
    await db.rawInsert(
      "INSERT INTO domains (nama_domain, client_id, tanggal_daftar, tanggal_expired, status) VALUES ('dewiblog.id', 2, '2026-02-10', '2026-05-10', 'expired')",
    );
    await db.rawInsert(
      "INSERT INTO domains (nama_domain, client_id, tanggal_daftar, tanggal_expired, status) VALUES ('rianportofolio.net', 3, '2026-03-01', '2027-03-01', 'suspended')",
    );
    await db.rawInsert(
      "INSERT INTO domains (nama_domain, client_id, tanggal_daftar, tanggal_expired, status) VALUES ('sitionline.com', 4, '2026-04-05', '2027-04-05', 'aktif')",
    );
    await db.rawInsert(
      "INSERT INTO domains (nama_domain, client_id, tanggal_daftar, tanggal_expired, status) VALUES ('tokobudi.id', 1, '2026-02-20', '2027-02-20', 'aktif')",
    );

    // Tickets
    await db.rawInsert(
      "INSERT INTO tickets (user_id, subjek, pesan, status, prioritas, tanggal_buat, tanggal_update) VALUES (1, 'Database Error 500', 'Halo admin, database saya tidak bisa diakses, muncul error 500.', 'open', 'high', '2026-05-18 10:00:00', '2026-05-18 10:00:00')",
    );
    await db.rawInsert(
      'INSERT INTO tickets (user_id, subjek, pesan, status, prioritas, tanggal_buat, tanggal_update) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        2,
        'Tanya Cara Setup SSL',
        "Bagaimana cara mengaktifkan SSL gratis Let's Encrypt di panel?",
        'in_progress',
        'medium',
        '2026-05-19 14:30:00',
        '2026-05-19 16:00:00',
      ],
    );
    await db.rawInsert(
      "INSERT INTO tickets (user_id, subjek, pesan, status, prioritas, tanggal_buat, tanggal_update) VALUES (4, 'Ganti Email Kontak', 'Saya ingin mengubah email kontak utama akun saya.', 'closed', 'low', '2026-05-15 08:00:00', '2026-05-15 11:00:00')",
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
        primaryValue: '/var/www/app/public_html',
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

  // --- CRUD DOMAINS ---
  Future<int> insertDomain(DomainModel domain) async {
    final db = await database;
    return await db.insert('domains', domain.toMap());
  }

  Future<List<DomainModel>> getDomains({
    String query = '',
    String statusFilter = 'Semua',
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (query.isNotEmpty) {
      whereClause += 'nama_domain LIKE ?';
      whereArgs.add('%$query%');
    }

    if (statusFilter != 'Semua') {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'status = ?';
      whereArgs.add(statusFilter.toLowerCase());
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'domains',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'tanggal_expired ASC',
    );

    return List.generate(maps.length, (i) => DomainModel.fromMap(maps[i]));
  }

  Future<int> updateDomain(DomainModel domain) async {
    final db = await database;
    return await db.update(
      'domains',
      domain.toMap(),
      where: 'id = ?',
      whereArgs: [domain.id],
    );
  }

  Future<int> deleteDomain(int id) async {
    final db = await database;
    return await db.delete('domains', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD USERS ---
  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<List<UserModel>> getUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT u.*, p.nama_paket 
      FROM users u
      LEFT JOIN packages p ON u.paket_id = p.id
    ''');
    return List.generate(maps.length, (i) => UserModel.fromMap(maps[i]));
  }

  Future<int> updateUser(UserModel user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD PACKAGES ---
  Future<int> insertPackage(PackageModel package) async {
    final db = await database;
    return await db.insert('packages', package.toMap());
  }

  Future<List<PackageModel>> getPackages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, COUNT(u.id) as jumlah_user
      FROM packages p 
      LEFT JOIN users u ON u.paket_id = p.id
      GROUP BY p.id
    ''');
    return List.generate(maps.length, (i) => PackageModel.fromMap(maps[i]));
  }

  Future<int> updatePackage(PackageModel package) async {
    final db = await database;
    return await db.update(
      'packages',
      package.toMap(),
      where: 'id = ?',
      whereArgs: [package.id],
    );
  }

  Future<int> deletePackage(int id) async {
    final db = await database;
    return await db.delete('packages', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD TICKETS ---
  Future<int> insertTicket(TicketModel ticket) async {
    final db = await database;
    return await db.insert('tickets', ticket.toMap());
  }

  Future<List<TicketModel>> getTickets(String statusFilter) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT t.*, u.nama 
      FROM tickets t
      JOIN users u ON t.user_id = u.id
      WHERE t.status = ?
      ORDER BY 
        CASE t.prioritas
          WHEN 'high' THEN 1
          WHEN 'medium' THEN 2
          WHEN 'low' THEN 3
          ELSE 4
        END ASC,
        t.tanggal_buat DESC
    ''',
      [statusFilter.toLowerCase()],
    );
    return List.generate(maps.length, (i) => TicketModel.fromMap(maps[i]));
  }

  Future<int> updateTicket(TicketModel ticket) async {
    final db = await database;
    return await db.update(
      'tickets',
      ticket.toMap(),
      where: 'id = ?',
      whereArgs: [ticket.id],
    );
  }

  Future<int> deleteTicket(int id) async {
    final db = await database;
    return await db.delete(
      'tickets',
      where: 'id = ? AND status = ?',
      whereArgs: [id, 'closed'],
    );
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

  // --- DASHBOARD AGGREGATIONS ---
  Future<int> getCount(String table) async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<int> getOpenTicketsCount() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM tickets WHERE status = 'open'",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getDomainsRegisteredPerMonth() async {
    final db = await database;
    // We group by the month of tanggal_daftar (format: yyyy-MM-dd)
    // The query returns the month (e.g. '01', '02', etc.) or 'yyyy-MM' and the count
    // SQLite strftime or substr can be used. Since tanggal_daftar is format yyyy-MM-dd,
    // substr(tanggal_daftar, 1, 7) will give yyyy-MM.
    final res = await db.rawQuery('''
      SELECT substr(tanggal_daftar, 1, 7) as month, COUNT(*) as count 
      FROM domains 
      GROUP BY month 
      ORDER BY month DESC 
      LIMIT 6
    ''');
    return res;
  }
}
