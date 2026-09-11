"""
Extraction Service
Bridge between LocalLLM and ExtractionParser for processing captures into memory candidates.
"""
from typing import List, Optional
from mindburst.ai.llm_engine import LocalLLMEngine, get_local_llm_engine
from mindburst.ai.prompt_manager import EXTRACTION_SYSTEM_PROMPT
from mindburst.ai.extraction_parser import ExtractionParser
from mindburst.database.models import Memory, Capture

class ExtractionService:
    def __init__(self, llm_engine: Optional[LocalLLMEngine] = None):
        self.llm = llm_engine or get_local_llm_engine()

    def extract_memories(self, capture: Capture) -> List[Memory]:
        """Runs local AI extraction on a saved capture and returns parsed Memory objects."""
        prompt = EXTRACTION_SYSTEM_PROMPT.format(user_text=capture.original_text)
        try:
            raw_response = self.llm.generate(prompt)
            return ExtractionParser.parse_llm_response(
                raw_response=raw_response,
                capture_id=capture.id,
                original_text=capture.original_text
            )
        except Exception as e:
            print(f"Extraction Service exception: {e}. Fallback triggered.")
            return [ExtractionParser._create_fallback_note(capture.id, capture.original_text)]
