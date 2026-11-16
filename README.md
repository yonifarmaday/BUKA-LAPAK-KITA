# Warung Sembako Dini — versi Cloudflare (Worker + D1)

Katalog belanja ala Shopee + member poin, untuk satu toko. Semua jalan di **Cloudflare** (tanpa Supabase):

| Bagian | Dipakai untuk |
|---|---|
| **Worker** (`src/index.js`) | API: login/daftar, data, pesanan, poin, hadiah, ongkir J&T, upload foto |
| **D1** (`schema.sql`, `seed.sql`) | database (produk, member, pesanan, poin, iklan, pengaturan) |
| **KV** | penyimpanan foto produk, video iklan, logo, QRIS |
| **public/** | tampilan web (PWA, bisa di-install di HP) |

Fitur sama dengan Warung Dini: katalog PACK/SLOF/BALL, **5 kategori** (Rokok, Sembako, Kebutuhan Rumah Tangga, Minuman, Makanan),
keranjang & checkout, ongkir J&T otomatis (RajaOngkir) atau tarif manual, QRIS / transfer bank, DP 10–50% (per member),
cetak label 100×150 mm, input & lacak resi, notifikasi pesanan baru, poin member + riwayat, tukar hadiah,
tukar poin jadi potongan harga (1 poin = Rp1, min. belanja Rp100.000), iklan Pop Up & Iklan Baris (gambar/MP4).

**Data awal:** 36 produk (kategori Rokok), pengaturan toko, iklan, tarif manual. Member, pesanan, riwayat poin, hadiah **kosong**.

---

## Cara pasang (lewat dashboard Cloudflare + GitHub)

### 1. Upload ke GitHub
Buat repo baru, upload **isi** folder ini (`public/`, `src/`, `schema.sql`, `seed.sql`, `wrangler.toml`, `README.md`, `.gitignore`).

### 2. Buat database D1
1. Cloudflare dashboard → **Storage & Databases → D1 SQL Database → Create** → nama: `dini-db`.
2. Buka database → tab **Console** → tempel seluruh isi **`schema.sql`** → **Execute**.
3. Tempel seluruh isi **`seed.sql`** → **Execute**.
4. Salin **Database ID** (ada di halaman database).

### 3. Buat KV untuk foto
**Storage & Databases → KV → Create** → nama: `dini-files` → salin **ID**-nya.

### 4. Isi ID di `wrangler.toml`
Ganti `GANTI-DENGAN-DATABASE-ID-D1` dan `GANTI-DENGAN-ID-KV` dengan ID dari langkah 2 & 3, lalu commit ke GitHub.

### 5. Deploy Worker
**Workers & Pages → Create → Import a repository** → pilih repo tadi → biarkan *Build command* kosong,
*Deploy command* `npx wrangler deploy` → **Deploy**. Setiap push ke GitHub akan deploy otomatis.

### 6. Isi secret
Worker → **Settings → Variables and Secrets → Add** (tipe **Secret**):

| Nama | Isi |
|---|---|
| `JWT_SECRET` | **wajib** — teks acak panjang (min. 32 karakter), misalnya hasil dari passwordsgenerator.net. Jangan dibagikan. |
| `RAJAONGKIR_KEY` | opsional — API key RajaOngkir Komerce untuk ongkir J&T otomatis. Tanpa ini, checkout memakai tarif manual per kota. |

### 7. Masuk sebagai admin
Buka alamat web Worker → **Masuk** → ID: **`ADMIN`** · password: **`admin12345`** → langsung diminta membuat password baru.

### 8. Pindahkan foto produk
Menu **Produk** → tombol **Pindahkan foto** (sekali saja). Foto produk, video iklan, dan logo disalin dari penyimpanan lama ke KV toko ini.

### 9. Atur toko
Menu **Pengaturan**: nama toko, logo, banner, WhatsApp, rekening bank, gambar QRIS, alamat & kota asal pengiriman (untuk ongkir), titik koordinat.

---

## Cara pasang lewat terminal (alternatif)
```bash
npm i -g wrangler && wrangler login
wrangler d1 create dini-db                 # salin database_id ke wrangler.toml
wrangler kv namespace create dini-files    # salin id ke wrangler.toml
wrangler d1 execute dini-db --remote --file=schema.sql
wrangler d1 execute dini-db --remote --file=seed.sql
wrangler secret put JWT_SECRET
wrangler secret put RAJAONGKIR_KEY         # opsional
wrangler deploy
```

## Catatan
- **Lupa password:** member minta reset ke admin via WhatsApp (tombol ada di halaman masuk). Admin → **Member & Poin → Reset PW** memberi password sementara; member wajib menggantinya saat masuk. (Versi ini tidak mengirim email.)
- **Login ID:** isian tanpa `@` otomatis jadi `<id>@dinimenganti.com` (contoh: `ADMIN` → `admin@dinimenganti.com`).
- **Batas file upload:** 24 MB per file (foto otomatis dikompres; video iklan sebaiknya < 10 MB).
- **Notifikasi pesanan baru** di halaman admin diperiksa tiap 15 detik.
- **Kuota gratis Cloudflare** (per hari): Worker 100.000 request, D1 5 juta baca / 100.000 tulis, KV 100.000 baca / 1.000 tulis — cukup untuk toko kecil–menengah.
- **Backup data:** D1 → database → **Time Travel** (bisa kembali ke titik waktu 30 hari terakhir), atau `wrangler d1 export dini-db --remote --output=backup.sql`.

Develop Program (MIZAN&NORMAN)
