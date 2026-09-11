"""
Memory Grounded Q&A Engine for MindBurst
"""
from typing import List, Optional
from mindburst.ai.llm_engine import LocalLLMEngine, get_local_llm_engine
from mindburst.ai.prompt_manager import ANSWERING_SYSTEM_PROMPT
from mindburst.database.models import Memory

class MemoryAnswerer:
    def __init__(self, llm_engine: Optional[LocalLLMEngine] = None):
        self.llm = llm_engine or get_local_llm_engine()

    def answer_question(self, question: str, retrieved_memories: List[Memory]) -> str:
        """Answers user question strictly based on retrieved memories without hallucination."""
        if not retrieved_memories:
            return "I couldn't find anything relevant in your memories."

        # Format retrieved memories for prompt context
        formatted_context_items = []
        for idx, mem in enumerate(retrieved_memories, 1):
            date_str = f" [Date: {mem.date}]" if mem.date else ""
            place_str = f" [Place: {', '.join(mem.places)}]" if mem.places else ""
            people_str = f" [Person: {', '.join(mem.people)}]" if mem.people else ""
            item_str = f" [Item: {', '.join(mem.items)}]" if mem.items else ""
            
            context_line = (
                f"{idx}. ({mem.type} / {mem.category}) Title: {mem.title} "
                f"| Details: {mem.details}{date_str}{place_str}{people_str}{item_str}"
            )
            formatted_context_items.append(context_line)

        memories_text = "\n".join(formatted_context_items)
        prompt = ANSWERING_SYSTEM_PROMPT.format(
            retrieved_memories=memories_text,
            user_question=question
        )

        return self.llm.generate(prompt)
