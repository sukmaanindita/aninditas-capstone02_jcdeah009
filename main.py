from db.database import DatabaseConnection
from scripts.etl import (
    AuditLogger,
    ExtractData,
    BronzeLoadData,
    TransformData,
    file_path,
    file_name1,
    file_name2,
    bronze_schema_path,
    transform_silver_path,
    gold_data_mart_path,
)
from dotenv import load_dotenv
import os

load_dotenv()
db_name = os.getenv("database_name")
db_user = os.getenv("database_user")
db_password = os.getenv("database_password")
db_host = os.getenv("database_host")
db_port = os.getenv("database_port")

db_url = f"postgresql+psycopg2://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"
database_connection = DatabaseConnection(db_url)

engine = database_connection.get_engine()
audit_logger = AuditLogger(engine)
bronze_loader = BronzeLoadData(engine, audit_logger)
transformer = TransformData(engine, audit_logger)
extractor = ExtractData(file_path=file_path, audit_logger=audit_logger)

transformer.execute_sql_file(
    bronze_schema_path,
    process_name="create_bronze_tables",
    target_schema="bronze",
    target_tables=[
        "raw_taxi_zone_lookup",
        "raw_yellow_taxi_trip",
    ],
)

df2 = extractor.extract_csv(file_name2)
if not df2.empty:
    bronze_loader.load_to_database(df2, "raw_taxi_zone_lookup")

df1 = extractor.extract_parquet(file_name1)
if not df1.empty:
    bronze_loader.load_to_database(df1, "raw_yellow_taxi_trip")

transformer.execute_sql_file(transform_silver_path)
transformer.execute_sql_file(
    gold_data_mart_path,
    process_name="create_gold_data_mart",
    target_schema="gold",
    target_tables=[
        "vw_trip_enriched",
        "vw_daily_trip_summary",
        "vw_zone_performance",
    ],
)
