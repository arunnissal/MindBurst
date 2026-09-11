"""
Data models for MindBurst SQLite storage
"""
from dataclasses import dataclass, field
from typing import Optional, List
from datetime import datetime

@dataclass
class Capture:
    id: Optional[int] = None
    original_text: str = ""
    input_source: str = "text" # 'text' or 'voice'
    created_at: Optional[str] = None

@dataclass
class Entity:
    id: Optional[int] = None
    memory_id: Optional[int] = None
    entity_type: str = ""  # 'person', 'place', 'item', 'project'
    name: str = ""

@dataclass
class Memory:
    id: Optional[int] = None
    capture_id: Optional[int] = None
    type: str = "Note"          # 'Carry', 'Task', 'Idea', 'Shopping', 'College', 'Project', 'Personal', 'Things to Use', 'Important', 'Note'
    title: str = ""
    details: str = ""
    date: Optional[str] = None    # e.g., "Tomorrow", "2026-09-04", null
    time: Optional[str] = None    # e.g., "10:00 AM", null
    category: str = "Notes"       # Default category
    retention: str = "Temporary" # 'Temporary', 'Keep Until Delete', 'Permanent'
    completed: bool = False
    completed_at: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None
    deleted_at: Optional[str] = None
    
    # Associated extracted entities
    people: List[str] = field(default_factory=list)
    places: List[str] = field(default_factory=list)
    items: List[str] = field(default_factory=list)
    projects: List[str] = field(default_factory=list)
    
    # Original capture reference
    original_text: Optional[str] = None
