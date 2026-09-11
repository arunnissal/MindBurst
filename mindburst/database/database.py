"""
SQLite Database Connection Manager and Schema Setup
"""
import sqlite3
import os
from typing import Optional
from mindburst.utils.helpers import get_app_dir

class DatabaseManager:
    _instance: Optional['DatabaseManager'] = None

    def __init__(self, db_path: Optional[str] = None):
        if db_path is None:
            db_dir = get_app_dir()
            self.db_path = os.path.join(db_dir, "mindburst.db")
        else:
            self.db_path = db_path
            
        self._init_db()

    @classmethod
    def get_instance(cls, db_path: Optional[str] = None) -> 'DatabaseManager':
        if cls._instance is None:
            cls._instance = DatabaseManager(db_path)
        return cls._instance

    def get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON;")
        return conn

    CURRENT_SCHEMA_VERSION = 2

    def _init_db(self):
        """Initialize SQLite database tables, migrations, and indexes."""
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        with self.get_connection() as conn:
            cursor = conn.cursor()
            
            # Captures table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS captures (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    original_text TEXT NOT NULL,
                    input_source TEXT NOT NULL DEFAULT 'text',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """)

            # Memories table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS memories (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    capture_id INTEGER NOT NULL,
                    type TEXT NOT NULL DEFAULT 'Note',
                    title TEXT NOT NULL,
                    details TEXT DEFAULT '',
                    date TEXT,
                    time TEXT,
                    category TEXT NOT NULL DEFAULT 'Notes',
                    retention TEXT NOT NULL DEFAULT 'Temporary',
                    completed INTEGER NOT NULL DEFAULT 0,
                    completed_at TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    deleted_at TIMESTAMP,
                    FOREIGN KEY (capture_id) REFERENCES captures (id) ON DELETE CASCADE
                );
            """)

            # Entities table (people, places, items, projects)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS entities (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    memory_id INTEGER NOT NULL,
                    entity_type TEXT NOT NULL,
                    name TEXT NOT NULL,
                    FOREIGN KEY (memory_id) REFERENCES memories (id) ON DELETE CASCADE
                );
            """)

            # Migrations tracking table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS schema_migrations (
                    version INTEGER PRIMARY KEY,
                    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """)

            # Create Indexes for fast retrieval and search
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_memories_category ON memories(category);")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_memories_retention ON memories(retention);")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_memories_completed ON memories(completed);")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_memories_deleted_at ON memories(deleted_at);")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_entities_memory ON entities(memory_id);")

            conn.commit()

        # Run pending schema migrations
        self._apply_migrations()

    def _apply_migrations(self):
        """Safely applies pending database schema migrations."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT MAX(version) as max_version FROM schema_migrations;")
            row = cursor.fetchone()
            current_version = row["max_version"] if (row and row["max_version"] is not None) else 0

            # Migration v1: Initial Schema
            if current_version < 1:
                cursor.execute("INSERT INTO schema_migrations (version) VALUES (1);")
                current_version = 1

            # Migration v2: Add input_source column to captures table if missing
            if current_version < 2:
                # Check if column already exists
                cursor.execute("PRAGMA table_info(captures);")
                columns = [r["name"] for r in cursor.fetchall()]
                if "input_source" not in columns:
                    cursor.execute("ALTER TABLE captures ADD COLUMN input_source TEXT NOT NULL DEFAULT 'text';")
                cursor.execute("INSERT INTO schema_migrations (version) VALUES (2);")

            conn.commit()

    def close(self):
        """Releases singleton instance reference if matched."""
        if DatabaseManager._instance is self:
            DatabaseManager._instance = None


