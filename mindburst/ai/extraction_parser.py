"""
Extraction Parser for MindBurst
Validates LLM JSON output against strict controlled schemas, normalizes relative dates via DateNormalizer,
deduplicates memory candidates within single extractions, and guarantees fallback to a simple Note memory.
"""
import json
import re
from typing import List, Dict, Any
from mindburst.database.models import Memory
from mindburst.utils.date_normalizer import DateNormalizer

ALLOWED_TYPES = {"Task", "Carry", "Shopping", "Idea", "Memory", "Note"}
ALLOWED_CATEGORIES = {
    "Carry", "Tasks", "Shopping", "Ideas", "College",
    "Projects", "Personal", "Things to Use", "Important", "Notes"
}
ALLOWED_RETENTIONS = {"Temporary", "Keep Until Delete", "Permanent"}

TYPE_TO_DEFAULT_CATEGORY = {
    "Carry": "Carry",
    "Task": "Tasks",
    "Shopping": "Shopping",
    "Idea": "Ideas",
    "Memory": "Notes",
    "Note": "Notes"
}

GENERIC_NOISE_WORDS = {
    "project", "the project", "a project", "that project", "our project",
    "assignment", "the assignment", "a assignment", "that assignment", "an assignment",
    "task", "the task", "a task", "that task",
    "thing", "the thing", "a thing", "that thing", "things",
    "item", "the item", "an item", "items",
    "place", "location", "someone", "somebody", "person"
}

class ExtractionParser:
    @staticmethod
    def parse_llm_response(raw_response: str, capture_id: int, original_text: str) -> List[Memory]:
        """
        Parses LLM output JSON into Memory instances.
        Normalizes dates, enums, removes exact duplicates, and guarantees fallback Note if invalid.
        """
        try:
            json_str = raw_response.strip()
            # Extract JSON block using regex if wrapped in markdown code blocks
            json_match = re.search(r'\{.*\}', json_str, re.DOTALL)
            if json_match:
                json_str = json_match.group(0)

            data = json.loads(json_str)
            raw_memories = data.get("memories", [])
            
            if not raw_memories or not isinstance(raw_memories, list):
                return [ExtractionParser._create_fallback_note(capture_id, original_text)]

            parsed_memories: List[Memory] = []
            seen_signatures = set()

            for item in raw_memories:
                if not isinstance(item, dict):
                    continue

                # 1. Normalize Type
                raw_type = str(item.get("type", "")).strip().title()
                memory_type = raw_type if raw_type in ALLOWED_TYPES else "Note"

                # 2. Normalize Title
                raw_title = str(item.get("title", "")).strip()
                title = raw_title if raw_title else original_text[:60]

                # 3. Normalize Category
                raw_cat = str(item.get("category", "")).strip().title()
                category = raw_cat if raw_cat in ALLOWED_CATEGORIES else TYPE_TO_DEFAULT_CATEGORY.get(memory_type, "Notes")

                # 4. Normalize Retention
                raw_ret = str(item.get("retention", "")).strip()
                # Case insensitive match for retention
                retention = "Temporary"
                for allowed_ret in ALLOWED_RETENTIONS:
                    if raw_ret.lower() == allowed_ret.lower():
                        retention = allowed_ret
                        break

                # 5. Normalize Date using DateNormalizer
                raw_date = item.get("date")
                normalized_date = DateNormalizer.resolve_date(str(raw_date)) if raw_date else None

                # 6. Normalize Entities
                people = ExtractionParser._clean_list(item.get("people"))
                places = ExtractionParser._clean_list(item.get("places"))
                items_list = ExtractionParser._clean_list(item.get("items"))
                projects = ExtractionParser._clean_list(item.get("projects"))

                # Deduplication signature
                sig = (memory_type, title.lower(), category, normalized_date)
                if sig in seen_signatures:
                    continue
                seen_signatures.add(sig)

                memory = Memory(
                    capture_id=capture_id,
                    type=memory_type,
                    title=title,
                    details=str(item.get("details") or original_text).strip(),
                    date=normalized_date,
                    time=str(item.get("time")).strip() if item.get("time") else None,
                    category=category,
                    retention=retention,
                    completed=bool(item.get("completed", False)),
                    people=people,
                    places=places,
                    items=items_list,
                    projects=projects,
                    original_text=original_text
                )
                parsed_memories.append(memory)

            return parsed_memories if parsed_memories else [ExtractionParser._create_fallback_note(capture_id, original_text)]

        except Exception as e:
            print(f"ExtractionParser validation error: {e}. Falling back to Note memory.")
            return [ExtractionParser._create_fallback_note(capture_id, original_text)]

    @staticmethod
    def _clean_list(val: Any) -> List[str]:
        cleaned = []
        if isinstance(val, list):
            raw_items = val
        elif isinstance(val, str) and val.strip():
            raw_items = [val]
        else:
            raw_items = []

        for x in raw_items:
            s = str(x).strip()
            if s and s.lower() not in GENERIC_NOISE_WORDS:
                cleaned.append(s)
        return cleaned

    @staticmethod
    def _create_fallback_note(capture_id: int, original_text: str) -> Memory:
        return Memory(
            capture_id=capture_id,
            type="Note",
            title=original_text.strip()[:60] if original_text else "Thought Note",
            details=original_text,
            date=None,
            time=None,
            category="Notes",
            retention="Temporary",
            completed=False,
            people=[],
            places=[],
            items=[],
            projects=[],
            original_text=original_text
        )
