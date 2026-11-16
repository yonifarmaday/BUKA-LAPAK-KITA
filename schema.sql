-- =====================================================================
-- Warung Sembako Dini — skema database Cloudflare D1 (SQLite)
-- Jalankan sekali:  npx wrangler d1 execute dini-db --remote --file=schema.sql
-- lalu isi data:    npx wrangler d1 execute dini-db --remote --file=seed.sql
-- =====================================================================
PRAGMA foreign_keys = ON;

-- akun login (password di-hash PBKDF2, tidak pernah dikirim ke browser)
CREATE TABLE IF NOT EXISTS auth_users (
  id          TEXT PRIMARY KEY,
  email       TEXT NOT NULL UNIQUE COLLATE NOCASE,
  pass_hash   TEXT NOT NULL,
  pw_ver      INTEGER NOT NULL DEFAULT 1,           -- naik tiap ganti password → sesi lama otomatis keluar
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS profiles (
  id            TEXT PRIMARY KEY REFERENCES auth_users(id) ON DELETE CASCADE,
  nama          TEXT NOT NULL DEFAULT '',
  no_hp         TEXT DEFAULT '',
  email         TEXT,
  alamat        TEXT DEFAULT '',
  kota          TEXT DEFAULT '',
  kecamatan     TEXT DEFAULT '',
  kelurahan     TEXT,
  kodepos       TEXT DEFAULT '',
  tujuan_id     TEXT,
  tujuan_label  TEXT,
  role          TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin','member')),
  poin          INTEGER NOT NULL DEFAULT 0 CHECK (poin >= 0),
  wajib_ganti_pw INTEGER NOT NULL DEFAULT 0,
  boleh_dp      INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS products (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  nama        TEXT NOT NULL,
  kategori    TEXT DEFAULT 'Rokok',
  deskripsi   TEXT DEFAULT '',
  harga       INTEGER NOT NULL DEFAULT 0 CHECK (harga >= 0),
  harga_slof  INTEGER CHECK (harga_slof IS NULL OR harga_slof >= 0),
  harga_ball  INTEGER CHECK (harga_ball IS NULL OR harga_ball >= 0),
  isi_slof    INTEGER NOT NULL DEFAULT 10 CHECK (isi_slof > 0),
  isi_ball    INTEGER NOT NULL DEFAULT 100 CHECK (isi_ball > 0),
  berat_gram  INTEGER NOT NULL DEFAULT 100 CHECK (berat_gram > 0),
  stok        INTEGER NOT NULL DEFAULT 0 CHECK (stok >= 0),
  foto_url    TEXT DEFAULT '',
  aktif       INTEGER NOT NULL DEFAULT 1,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS orders (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  kode               TEXT NOT NULL UNIQUE,
  member_id          TEXT NOT NULL REFERENCES profiles(id),
  items              TEXT NOT NULL DEFAULT '[]',     -- JSON
  subtotal           INTEGER NOT NULL DEFAULT 0,
  berat_gram         INTEGER NOT NULL DEFAULT 0,
  kurir              TEXT NOT NULL DEFAULT 'J&T',
  layanan            TEXT DEFAULT 'EZ',
  ongkir             INTEGER NOT NULL DEFAULT 0,
  etd                TEXT DEFAULT '',
  total              INTEGER NOT NULL DEFAULT 0,
  penerima_nama      TEXT NOT NULL,
  penerima_hp        TEXT NOT NULL,
  penerima_alamat    TEXT NOT NULL,
  penerima_kota      TEXT DEFAULT '',
  penerima_kecamatan TEXT DEFAULT '',
  penerima_kodepos   TEXT DEFAULT '',
  tujuan_id          TEXT DEFAULT '',
  catatan            TEXT DEFAULT '',
  status             TEXT NOT NULL DEFAULT 'menunggu' CHECK (status IN ('menunggu','dikonfirmasi','dikirim','selesai','batal')),
  resi               TEXT DEFAULT '',
  dicetak_at         TEXT,
  metode_bayar       TEXT NOT NULL DEFAULT 'qris' CHECK (metode_bayar IN ('qris','transfer')),
  dp_persen          INTEGER NOT NULL DEFAULT 0 CHECK (dp_persen IN (0,10,20,30,40,50)),
  dp_nominal         INTEGER NOT NULL DEFAULT 0 CHECK (dp_nominal >= 0),
  status_bayar       TEXT NOT NULL DEFAULT 'belum' CHECK (status_bayar IN ('belum','dp','lunas')),
  poin_dipakai       INTEGER NOT NULL DEFAULT 0,
  potongan_poin      INTEGER NOT NULL DEFAULT 0,
  created_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (status <> 'selesai' OR status_bayar = 'lunas')   -- pesanan selesai wajib lunas
);
CREATE INDEX IF NOT EXISTS idx_orders_member ON orders(member_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

CREATE TABLE IF NOT EXISTS point_logs (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id    TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  delta        INTEGER NOT NULL,
  saldo_akhir  INTEGER NOT NULL,
  keterangan   TEXT DEFAULT '',
  oleh         TEXT,
  created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_logs_member ON point_logs(member_id);

CREATE TABLE IF NOT EXISTS rewards (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  nama        TEXT NOT NULL,
  deskripsi   TEXT DEFAULT '',
  poin        INTEGER NOT NULL CHECK (poin > 0),
  stok        INTEGER NOT NULL DEFAULT 0 CHECK (stok >= 0),
  foto_url    TEXT DEFAULT '',
  aktif       INTEGER NOT NULL DEFAULT 1,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS redemptions (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id      TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reward_id      INTEGER NOT NULL,
  reward_nama    TEXT NOT NULL,
  poin           INTEGER NOT NULL,
  status         TEXT NOT NULL DEFAULT 'menunggu' CHECK (status IN ('menunggu','disetujui','ditolak')),
  catatan_admin  TEXT DEFAULT '',
  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS tarif_manual (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  kota          TEXT NOT NULL UNIQUE,
  tarif_per_kg  INTEGER NOT NULL,
  etd           TEXT DEFAULT '2-3 hari'
);

CREATE TABLE IF NOT EXISTS settings (
  key    TEXT PRIMARY KEY,
  value  TEXT DEFAULT ''
);

CREATE TABLE IF NOT EXISTS popups (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  judul        TEXT NOT NULL DEFAULT '',
  gambar_url   TEXT NOT NULL,
  link         TEXT DEFAULT '',
  teks_tombol  TEXT DEFAULT '',
  posisi       TEXT NOT NULL DEFAULT 'popup' CHECK (posisi IN ('popup','baris')),
  aktif        INTEGER NOT NULL DEFAULT 1,
  mulai        TEXT,
  selesai      TEXT,
  urutan       INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- nomor urut kode pesanan (ORDyymmddNNNNN)
CREATE TABLE IF NOT EXISTS counters (
  name   TEXT PRIMARY KEY,
  value  INTEGER NOT NULL DEFAULT 0
);
INSERT OR IGNORE INTO counters(name, value) VALUES ('order_kode', 0);

-- pengaman: satu pesanan/penukaran hanya bisa dibatalkan/diproses sekali
CREATE TABLE IF NOT EXISTS proses_sekali (
  ref  TEXT PRIMARY KEY
);
