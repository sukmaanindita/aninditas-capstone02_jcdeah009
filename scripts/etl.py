import pandas as pd
import time
from datetime import datetime
from pathlib import Path
from sqlalchemy import text

file_path = Path("./data/raw/")
file_name1 = "yellow_tripdata_2026-01.parquet"
file_name2 = "taxi_zone_lookup_table.csv"
transform_silver_path = Path("./sql/init/02_transform_and_load_silver.sql")
gold_data_mart_path = Path("./sql/init/03_create_gold_data_mart.sql")


def print_log(message: str):
    print(message, flush=True)


def format_duration(start_time: float) -> str:
    return f"{time.perf_counter() - start_time:.2f}s"


def duration_seconds(start_time: float) -> float:
    return round(time.perf_counter() - start_time, 2)


class AuditLogger:
    def __init__(self, engine):
        self.engine = engine
        self.ensure_table()

    def ensure_table(self):
        sql_script = """
        CREATE SCHEMA IF NOT EXISTS audit;

        CREATE TABLE IF NOT EXISTS audit.etl_process_log (
            log_id BIGSERIAL PRIMARY KEY,
            process_name VARCHAR(100),
            source_name VARCHAR(255),
            target_schema VARCHAR(100),
            target_table VARCHAR(100),
            status VARCHAR(20),
            row_count BIGINT,
            started_at TIMESTAMP,
            finished_at TIMESTAMP,
            duration_seconds NUMERIC,
            error_message TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE INDEX IF NOT EXISTS idx_etl_process_log_created_at
        ON audit.etl_process_log (created_at);

        CREATE INDEX IF NOT EXISTS idx_etl_process_log_status
        ON audit.etl_process_log (status);

        CREATE INDEX IF NOT EXISTS idx_etl_process_log_process_name
        ON audit.etl_process_log (process_name);
        """
        with self.engine.begin() as conn:
            conn.exec_driver_sql(sql_script)

    def log_process(
        self,
        process_name: str,
        status: str,
        started_at: datetime,
        finished_at: datetime,
        duration: float,
        source_name: str | None = None,
        target_schema: str | None = None,
        target_table: str | None = None,
        row_count: int | None = None,
        error_message: str | None = None,
    ):
        insert_sql = text("""
            INSERT INTO audit.etl_process_log (
                process_name,
                source_name,
                target_schema,
                target_table,
                status,
                row_count,
                started_at,
                finished_at,
                duration_seconds,
                error_message
            )
            VALUES (
                :process_name,
                :source_name,
                :target_schema,
                :target_table,
                :status,
                :row_count,
                :started_at,
                :finished_at,
                :duration_seconds,
                :error_message
            )
        """)
        try:
            with self.engine.begin() as conn:
                conn.execute(
                    insert_sql,
                    {
                        "process_name": process_name,
                        "source_name": source_name,
                        "target_schema": target_schema,
                        "target_table": target_table,
                        "status": status,
                        "row_count": row_count,
                        "started_at": started_at,
                        "finished_at": finished_at,
                        "duration_seconds": duration,
                        "error_message": error_message,
                    },
                )
        except Exception as e:
            print_log(f"⚠️[WARN] === Gagal menulis audit log: {e} ===")


class ExtractData:
    def __init__(self, file_path: Path, audit_logger: AuditLogger | None = None):
        self.file_path = file_path
        self.audit_logger = audit_logger

    def extract_parquet(self, file_name: str) -> pd.DataFrame:
        start_time = time.perf_counter()
        started_at = datetime.now()
        print_log(f"⏳[START] === Extract parquet dimulai: {file_name} ===")
        try:
            df = pd.read_parquet(self.file_path / file_name)
            finished_at = datetime.now()
            duration = duration_seconds(start_time)
            if self.audit_logger:
                self.audit_logger.log_process(
                    process_name="extract_parquet",
                    source_name=file_name,
                    status="SUCCESS",
                    row_count=len(df),
                    started_at=started_at,
                    finished_at=finished_at,
                    duration=duration,
                )
            print_log(f"✅[OK] === File berhasil dimuat: {file_name} ===")
            print_log(f"✅[OK] === Extract parquet selesai | rows: {len(df)} | duration: {duration:.2f}s ===")
            return df
        except Exception as e:
            finished_at = datetime.now()
            duration = duration_seconds(start_time)
            if self.audit_logger:
                self.audit_logger.log_process(
                    process_name="extract_parquet",
                    source_name=file_name,
                    status="FAILED",
                    row_count=0,
                    started_at=started_at,
                    finished_at=finished_at,
                    duration=duration,
                    error_message=str(e),
                )
            print_log(f"❌[ERROR] === Gagal memuat file {file_name}: {e} | duration: {duration:.2f}s ===")
            return pd.DataFrame()

    def extract_csv(self, file_name: str) -> pd.DataFrame:
        start_time = time.perf_counter()
        started_at = datetime.now()
        print_log(f"⏳[START] === Extract csv dimulai: {file_name} ===")
        try:
            df = pd.read_csv(self.file_path / file_name)
            finished_at = datetime.now()
            duration = duration_seconds(start_time)
            if self.audit_logger:
                self.audit_logger.log_process(
                    process_name="extract_csv",
                    source_name=file_name,
                    status="SUCCESS",
                    row_count=len(df),
                    started_at=started_at,
                    finished_at=finished_at,
                    duration=duration,
                )
            print_log(f"✅[OK] === File berhasil dimuat: {file_name} ===")
            print_log(f"✅[OK] === Extract csv selesai | rows: {len(df)} | duration: {duration:.2f}s ===")
            return df
        except Exception as e:
            finished_at = datetime.now()
            duration = duration_seconds(start_time)
            if self.audit_logger:
                self.audit_logger.log_process(
                    process_name="extract_csv",
                    source_name=file_name,
                    status="FAILED",
                    row_count=0,
                    started_at=started_at,
                    finished_at=finished_at,
                    duration=duration,
                    error_message=str(e),
                )
            print_log(f"❌[ERROR] === Gagal memuat file {file_name}: {e} | duration: {duration:.2f}s ===")
            return pd.DataFrame()
        
    
        
class BronzeLoadData:
    def __init__(self, engine, audit_logger: AuditLogger | None = None):
        self.engine = engine
        self.audit_logger = audit_logger

    def load_to_database(self, df: pd.DataFrame, table_name: str, schema: str = "bronze"):
        start_time = time.perf_counter()
        started_at = datetime.now()
        print_log(f"⏳[START] === Load bronze dimulai | table: {schema}.{table_name} | rows: {len(df)} ===")
        try:
            df.columns = [column.lower() for column in df.columns]
            with self.engine.begin() as conn:
                conn.exec_driver_sql(f"TRUNCATE TABLE {schema}.{table_name} RESTART IDENTITY CASCADE")
            df.to_sql(table_name, con=self.engine, schema=schema, if_exists="append", index=False)
            finished_at = datetime.now()
            duration = duration_seconds(start_time)
            if self.audit_logger:
                self.audit_logger.log_process(
                    process_name="load_bronze",
                    target_schema=schema,
                    target_table=table_name,
                    status="SUCCESS",
                    row_count=len(df),
                    started_at=started_at,
                    finished_at=finished_at,
                    duration=duration,
                )
            print_log(f"✅[OK] === Data berhasil dimuat ke tabel {schema}.{table_name} ===")
            print_log(f"✅[OK] === Proses load bronze selesai | table: {schema}.{table_name} | total rows: {len(df)} | duration: {duration:.2f}s ===")
        except Exception as e:
            finished_at = datetime.now()
            duration = duration_seconds(start_time)
            if self.audit_logger:
                self.audit_logger.log_process(
                    process_name="load_bronze",
                    target_schema=schema,
                    target_table=table_name,
                    status="FAILED",
                    row_count=len(df),
                    started_at=started_at,
                    finished_at=finished_at,
                    duration=duration,
                    error_message=str(e),
                )
            print_log(f"❌[ERROR] === Load bronze gagal | table: {schema}.{table_name} | error: {e} | duration: {duration:.2f}s ===")
            raise


class SilverLoadData:
    def __init__(self, engine, audit_logger: AuditLogger | None = None):
        self.engine = engine
        self.audit_logger = audit_logger

    def load_to_database(self, df: pd.DataFrame, table_name: str, schema: str = "silver"):
        start_time = time.perf_counter()
        started_at = datetime.now()
        print_log(f"⏳[START] === Load silver dimulai | table: {schema}.{table_name} | rows: {len(df)} ===")
        try:
            df.columns = [column.lower() for column in df.columns]
            df.to_sql(table_name, con=self.engine, schema=schema, if_exists="replace", index=False) ## if exist, the data will be replaced with the latest
            finished_at = datetime.now()
            duration = duration_seconds(start_time)
            if self.audit_logger:
                self.audit_logger.log_process(
                    process_name="load_silver",
                    target_schema=schema,
                    target_table=table_name,
                    status="SUCCESS",
                    row_count=len(df),
                    started_at=started_at,
                    finished_at=finished_at,
                    duration=duration,
                )
            print_log(f"✅[OK] === Data berhasil dimuat ke tabel {schema}.{table_name} ===")
            print_log(f"✅[OK] === Proses load silver selesai | table: {schema}.{table_name} | total rows: {len(df)} | duration: {duration:.2f}s ===")
        except Exception as e:
            finished_at = datetime.now()
            duration = duration_seconds(start_time)
            if self.audit_logger:
                self.audit_logger.log_process(
                    process_name="load_silver",
                    target_schema=schema,
                    target_table=table_name,
                    status="FAILED",
                    row_count=len(df),
                    started_at=started_at,
                    finished_at=finished_at,
                    duration=duration,
                    error_message=str(e),
                )
            print_log(f"❌[ERROR] === Load silver gagal | table: {schema}.{table_name} | error: {e} | duration: {duration:.2f}s ===")
            raise


class TransformData:
    def __init__(self, engine, audit_logger: AuditLogger | None = None):
        self.engine = engine
        self.audit_logger = audit_logger

    def execute_sql_file(
        self,
        sql_path: Path,
        process_name: str = "transform_silver",
        target_schema: str = "silver",
        target_tables: list[str] | None = None,
    ):
        start_time = time.perf_counter()
        started_at = datetime.now()
        print_log(f"⏳[START] === Transform dan Load SQL dimulai: {sql_path} ===")
        try:
            if target_tables is None:
                target_tables = [
                    "cleaned_yellow_taxi_trip",
                    "taxi_zones_mapping",
                    "data_quality_issues",
                ]

            sql_script = sql_path.read_text()
            with self.engine.begin() as conn:
                conn.exec_driver_sql(sql_script)
                table_counts = {
                    table_name: conn.exec_driver_sql(
                        f"SELECT COUNT(*) FROM {target_schema}.{table_name}"
                    ).scalar()
                    for table_name in target_tables
                }
            finished_at = datetime.now()
            duration = duration_seconds(start_time)
            if self.audit_logger:
                for table_name, row_count in table_counts.items():
                    self.audit_logger.log_process(
                        process_name=process_name,
                        source_name=str(sql_path),
                        target_schema=target_schema,
                        target_table=table_name,
                        status="SUCCESS",
                        row_count=row_count,
                        started_at=started_at,
                        finished_at=finished_at,
                        duration=duration,
                    )
            print_log(f"✅[OK] === Transform dan Load SQL berhasil dijalankan: {sql_path} | duration: {duration:.2f}s ===")
        except Exception as e:
            finished_at = datetime.now()
            duration = duration_seconds(start_time)
            if self.audit_logger:
                self.audit_logger.log_process(
                    process_name=process_name,
                    source_name=str(sql_path),
                    target_schema=target_schema,
                    status="FAILED",
                    started_at=started_at,
                    finished_at=finished_at,
                    duration=duration,
                    error_message=str(e),
                )
            print_log(f"❌[ERROR] === Transform dan Load SQL gagal dijalankan: {e} | duration: {duration:.2f}s ===")
            raise
