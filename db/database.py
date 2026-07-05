from sqlalchemy import create_engine

class DatabaseConnection:
    def __init__(self, db_url: str):
        self.db_url = db_url
        self.engine = None

    def connect(self):
        try:
            self.engine = create_engine(self.db_url)
            print("✅[OK] === Database connection established ===")
        except Exception as e:
            print(f"❌[ERROR] === Failed to connect to database: {e} ===")

    def get_engine(self):
        if self.engine is None:
            self.connect()
        return self.engine