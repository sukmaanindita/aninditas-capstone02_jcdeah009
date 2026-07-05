# NYC Yellow Taxi Trip Data Pipeline

## 1. Deskripsi Project

Project ini membangun pipeline ETL untuk data NYC Yellow Taxi Trip bulan Januari 2026. Data diproses dari file raw lokal, dimuat ke PostgreSQL, dibersihkan pada layer silver, lalu disiapkan sebagai data mart pada layer gold.

Tujuan project:

- Memuat data trip taxi dan lookup zone ke PostgreSQL.
- Menerapkan medallion architecture: bronze, silver, gold.
- Melakukan cleansing data dan pemisahan data invalid.
- Membuat gold view untuk kebutuhan analisis.
- Menyimpan audit log proses ETL ke schema `audit`.
- Menjawab business questions menggunakan SQL.

## 2. Cara Menjalankan Docker Compose

Pastikan Docker sudah berjalan, lalu jalankan dari folder project:

```bash
cd /Users/anninditas/Desktop/Purwadhika/JCDEAH-009/Capstone02
docker compose up -d
```

Service PostgreSQL berjalan di port host `5439` dan container port `5432`.

Untuk reset database dan menjalankan ulang init SQL dari awal:

```bash
docker compose down -v
docker compose up -d
```

Catatan: script SQL di `sql/init` hanya otomatis dijalankan oleh Docker saat volume database pertama kali dibuat.

## 3. Cara Membuat Schema Database

Schema dibuat melalui file SQL init:

- `sql/init/01_create_and_load_bronze.sql`
- `sql/init/02_transform_and_load_silver.sql`
- `sql/init/03_create_gold_data_mart.sql`

Schema yang digunakan:

- `bronze`: menyimpan data raw hasil load.
- `silver`: menyimpan data cleaned, mapping zone, dan data quality issues.
- `gold`: menyimpan view data mart.
- `audit`: menyimpan log proses ETL.

Schema `audit` dibuat otomatis dari class `AuditLogger` di `scripts/etl.py`.

## 4. Cara Load Data

Data raw disimpan di:

```text
data/raw/yellow_tripdata_2026-01.parquet
data/raw/taxi_zone_lookup_table.csv
```

Load data dilakukan melalui script:

```bash
bash auto_command_script.sh
```

Script tersebut menjalankan:

```bash
python3 -u main.py
```

Urutan load di `main.py`:

1. Extract `taxi_zone_lookup_table.csv`.
2. Load ke `bronze.raw_taxi_zone_lookup`.
3. Extract `yellow_tripdata_2026-01.parquet`.
4. Load ke `bronze.raw_yellow_taxi_trip`.
5. Jalankan transform silver.
6. Jalankan create/replace gold views.

Log terminal disimpan ke:

```text
logs/pipeline.log
```

Log proses ETL disimpan ke:

```sql
audit.etl_process_log
```

## 5. Alur Medallion Architecture

### Bronze

Layer bronze menyimpan data mentah yang sudah masuk ke database.

Tabel:

- `bronze.raw_taxi_zone_lookup`
- `bronze.raw_yellow_taxi_trip`

Pada layer ini, data masih mendekati bentuk raw source.

### Silver

Layer silver berisi data yang sudah dibersihkan dan siap digunakan untuk analisis lanjutan.

Tabel:

- `silver.cleaned_yellow_taxi_trip`
- `silver.taxi_zones_mapping`
- `silver.data_quality_issues`

Transformasi silver mencakup:

- Filter data null pada kolom penting.
- Filter trip dengan durasi tidak valid.
- Filter `passenger_count <= 0`.
- Filter `trip_distance <= 0`.
- Filter `total_amount < 0`.
- Membuat kolom turunan seperti `pickup_date`, `pickup_time`, `pickup_day_name`, `is_weekend`, dan `trip_duration_minutes`.
- Memisahkan data invalid ke `silver.data_quality_issues`.

### Gold

Layer gold berisi view data mart untuk kebutuhan analisis.

View:

- `gold.vw_trip_enriched`
- `gold.vw_daily_trip_summary`
- `gold.vw_zone_performance`

Mapping `pickup_location` dan `dropoff_location` dilakukan pada layer gold melalui join ke `silver.taxi_zones_mapping`.

## 6. Cara Menjalankan Transformasi SQL

Transformasi SQL dijalankan otomatis dari `main.py`:

```python
transformer.execute_sql_file(transform_silver_path)
transformer.execute_sql_file(gold_data_mart_path, ...)
```

File transformasi:

```text
sql/init/02_transform_and_load_silver.sql
sql/init/03_create_gold_data_mart.sql
```

Jika ingin menjalankan manual dari database client, jalankan berurutan:

```sql
\i sql/init/02_transform_and_load_silver.sql
\i sql/init/03_create_gold_data_mart.sql
```

## 7. Cara Menjalankan Query Analisis

Query analisis disimpan di:

```text
business_questions.sql
```

Jalankan query tersebut melalui database client seperti DBeaver, TablePlus, pgAdmin, atau psql.

Contoh query:

```sql
SELECT *
FROM gold.vw_daily_trip_summary
ORDER BY pickup_date;
```

Untuk melihat audit log:

```sql
SELECT *
FROM audit.etl_process_log
ORDER BY created_at DESC;
```

## 8. Struktur Folder

```text
Capstone02/
├── auto_command_script.sh
├── business_questions.sql
├── docker-compose.yaml
├── main.py
├── reqirements.txt
├── data/
│   └── raw/
│       ├── taxi_zone_lookup_table.csv
│       └── yellow_tripdata_2026-01.parquet
├── db/
│   └── database.py
├── logs/
│   └── pipeline.log
├── scripts/
│   └── etl.py
└── sql/
    └── init/
        ├── 01_create_and_load_bronze.sql
        ├── 02_transform_and_load_silver.sql
        └── 03_create_gold_data_mart.sql
```

## 9. ERD dan Desain Tabel

Desain database menggunakan empat schema utama: `bronze`, `silver`, `gold`, dan `audit`.

Relasi utama:

```text
bronze.raw_taxi_zone_lookup
    locationid PK
        ↑
        ├── bronze.raw_yellow_taxi_trip.pulocationid
        └── bronze.raw_yellow_taxi_trip.dolocationid

silver.taxi_zones_mapping
    locationid PK
        ↑
        ├── gold.vw_trip_enriched.pulocationid
        └── gold.vw_trip_enriched.dolocationid
```

Tabel utama:

- `bronze.raw_taxi_zone_lookup`: lookup lokasi taxi zone.
- `bronze.raw_yellow_taxi_trip`: data trip raw dari parquet.
- `silver.cleaned_yellow_taxi_trip`: data trip valid setelah cleansing.
- `silver.taxi_zones_mapping`: mapping taxi zone dari bronze.
- `silver.data_quality_issues`: data invalid beserta tipe error.
- `audit.etl_process_log`: log proses ETL.

Gold layer dibuat sebagai view, bukan table fisik, supaya data mart selalu mengikuti data silver terbaru.

## 10. Daftar Business Questions

Business questions yang dijawab di `business_questions.sql`:

1. Berapa total valid trips setelah proses cleansing?
2. Bagaimana total trips dan rata-rata metrik trip pada weekend vs weekday?
3. Payment type apa yang memiliki total trips dan revenue tertinggi?
4. Pickup location mana yang memiliki average trip distance tertinggi?
5. Pickup location mana yang memiliki average revenue tertinggi?
6. Bagaimana summary trips berdasarkan pickup date?
7. Error type apa yang paling banyak muncul pada data quality issues?
8. Apa top 10 pickup location dengan average revenue tertinggi?
9. Pickup location mana yang memiliki average tip amount terendah?
10. Bagaimana perbandingan revenue harian terhadap rata-rata revenue harian?
11. Bagaimana ranking pickup location berdasarkan total revenue?
12. Bagaimana ranking revenue dalam setiap borough?
13. Bagaimana moving average 7 hari untuk durasi trip?

## 11. Kendala Teknis dan Asumsi

Kendala teknis:

- File SQL di `/docker-entrypoint-initdb.d` hanya otomatis dijalankan saat volume PostgreSQL pertama kali dibuat.
- `pandas.to_sql(if_exists="replace")` dapat menghapus constraint, sehingga load bronze menggunakan pola `TRUNCATE TABLE ... RESTART IDENTITY CASCADE` lalu `append`.
- `raw_taxi_zone_lookup` harus diload sebelum `raw_yellow_taxi_trip` karena `pulocationid` dan `dolocationid` mengacu ke `locationid`.
- Data invalid perlu dipisahkan agar tidak mengganggu analisis di layer silver dan gold.
- Gold layer menggunakan view, sehingga tidak bisa dibuat index langsung seperti table biasa.

Asumsi:

- `pulocationid` dan `dolocationid` berisi ID lokasi yang valid dan dapat dicocokkan dengan `locationid`.
- Trip valid memiliki `tpep_dropoff_datetime > tpep_pickup_datetime`.
- Trip valid memiliki `passenger_count > 0`.
- Trip valid memiliki `trip_distance > 0`.
- Trip valid memiliki `total_amount >= 0`.
- Field `payment_type` tetap disimpan sesuai value source.
- Data mart gold digunakan untuk kebutuhan analisis dan dashboard, bukan sebagai storage raw.
