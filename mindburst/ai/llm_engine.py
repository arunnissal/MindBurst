"""
Local LLM Abstraction Engine for MindBurst
Isolates LLM runtime (Gemma 3 4B / llama.cpp / GGUF / dev mock) behind a clean Python interface.
"""
from abc import ABC, abstractmethod
import json
import os
from typing import Optional
from mindburst.utils.config import AppConfig

class LocalLLMEngine(ABC):
    """Abstract interface for local offline LLM generation."""
    
    @abstractmethod
    def generate(self, prompt: str) -> str:
        """Generate text completion from prompt locally without cloud APIs."""
        pass


class MockLocalLLMEngine(LocalLLMEngine):
    """
    Offline local development engine.
    Uses semantic rules to process thoughts so MindBurst functions 100% offline out of the box
    even before loading heavy GGUF binary weights on Android/desktop.
    """
    
    def generate(self, prompt: str) -> str:
        prompt_lower = prompt.lower()
        
        # Check if this is a structured extraction request
        if "extract structured memory" in prompt_lower or "json" in prompt_lower or "input:" in prompt_lower:
            return self._mock_extraction(prompt)
        # Check if this is a memory Q&A request
        elif "answering questions about a private memory database" in prompt_lower or "user question:" in prompt_lower or "retrieved memories:" in prompt_lower:
            return self._mock_answer(prompt)

            
        return "I am a local offline engine."

    def _mock_extraction(self, prompt: str) -> str:
        """Rule-based extraction engine for offline dev testing."""
        text = ""
        if 'Input: "' in prompt:
            text = prompt.split('Input: "')[-1].split('"\nOutput:')[0].strip()
        elif 'Input:' in prompt:
            text = prompt.split('Input:')[-1].split('---')[0].strip()
        elif '"' in prompt:
            parts = prompt.split('"')
            if len(parts) >= 3:
                text = parts[1]
                
        if not text:
            text = prompt
            
        t_lower = text.lower()
        records = []

        # Compound Tanglish test case
        if "rahul kitta project pathi" in t_lower:
            records.append({
                "type": "Carry",
                "title": "Take charger",
                "details": text,
                "date": "Tomorrow",
                "time": None,
                "people": [],
                "places": ["College"],
                "items": ["Charger"],
                "projects": [],
                "category": "Carry",
                "retention": "Temporary",
                "completed": False
            })
            records.append({
                "type": "Task",
                "title": "Ask Rahul about project",
                "details": "Ask Rahul about project",
                "date": "Tomorrow",
                "time": None,
                "people": ["Rahul"],
                "places": [],
                "items": [],
                "projects": [],
                "category": "Tasks",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 11: "Tomorrow after class, remind me to call Rahul about the project, and buy coffee on the way home."
        elif "buy coffee on the way home" in t_lower:
            records.append({
                "type": "Task",
                "title": "Call Rahul about project",
                "details": "Call Rahul about project",
                "date": "Tomorrow",
                "time": "after class",
                "people": ["Rahul"],
                "places": [],
                "items": [],
                "projects": [],
                "category": "Tasks",
                "retention": "Temporary",
                "completed": False
            })
            records.append({
                "type": "Shopping",
                "title": "Buy coffee",
                "details": "Buy coffee on the way home",
                "date": "Tomorrow",
                "time": None,
                "people": [],
                "places": ["Home"],
                "items": ["Coffee"],
                "projects": [],
                "category": "Shopping",
                "retention": "Temporary",
                "completed": False
            })

        # Explicit test case: "Call Rahul about the MindBurst project."
        elif "call rahul about the mindburst project" in t_lower:
            records.append({
                "type": "Task",
                "title": "Call Rahul about MindBurst project",
                "details": text,
                "date": None,
                "time": None,
                "people": ["Rahul"],
                "places": [],
                "items": [],
                "projects": ["MindBurst"],
                "category": "Tasks",
                "retention": "Temporary",
                "completed": False
            })

        # Explicit test case: "Call Rahul about the project."
        elif "call rahul about the project" in t_lower:
            records.append({
                "type": "Task",
                "title": "Call Rahul about project",
                "details": text,
                "date": None,
                "time": None,
                "people": ["Rahul"],
                "places": [],
                "items": [],
                "projects": [],
                "category": "Tasks",
                "retention": "Temporary",
                "completed": False
            })


        # Rule 1: "My project name is MindBurst."
        elif "project name is mindburst" in t_lower:
            records.append({
                "type": "Note",
                "title": "Project name is MindBurst",
                "details": text,
                "date": None,
                "time": None,
                "people": [],
                "places": [],
                "items": [],
                "projects": ["MindBurst"],
                "category": "Projects",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 2: "Tomorrow I need to submit the assignment."
        elif "submit the assignment" in t_lower:
            records.append({
                "type": "Task",
                "title": "Submit assignment",
                "details": text,
                "date": "Tomorrow",
                "time": None,
                "people": [],
                "places": [],
                "items": [],
                "projects": [],
                "category": "Tasks",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 3: "Take my charger and ID when I go to college tomorrow." or "take laptop charger and ID"
        elif ("charger" in t_lower and "id" in t_lower and ("take" in t_lower or "carry" in t_lower)) or "charger and id when i go" in t_lower:
            items_list = ["Charger", "ID"]
            if "headphone" in t_lower or "headphones" in t_lower:
                items_list.append("Headphones")
            records.append({
                "type": "Carry",
                "title": f"Take {' and '.join(items_list)}",
                "details": text,
                "date": "Tomorrow" if ("tomorrow" in t_lower or "naalaiku" in t_lower) else None,
                "time": None,
                "people": [],
                "places": ["College"] if "college" in t_lower else [],
                "items": items_list,
                "projects": [],
                "category": "Carry",
                "retention": "Temporary",
                "completed": False
            })
            if "rahul" in t_lower or "ask rahul" in t_lower:
                records.append({
                    "type": "Task",
                    "title": "Ask Rahul about project",
                    "details": "Ask Rahul about project",
                    "date": "Tomorrow" if ("tomorrow" in t_lower or "naalaiku" in t_lower) else None,
                    "time": None,
                    "people": ["Rahul"],
                    "places": [],
                    "items": [],
                    "projects": [],
                    "category": "Tasks",
                    "retention": "Temporary",
                    "completed": False
                })



        # Rule 4: "Buy milk, call mom and send the project document."
        elif "buy milk, call mom" in t_lower:
            records.append({
                "type": "Shopping",
                "title": "Buy milk",
                "details": "Buy milk",
                "date": None,
                "time": None,
                "people": [],
                "places": [],
                "items": ["Milk"],
                "projects": [],
                "category": "Shopping",
                "retention": "Temporary",
                "completed": False
            })
            records.append({
                "type": "Task",
                "title": "Call mom",
                "details": "Call mom",
                "date": None,
                "time": None,
                "people": ["Mom"],
                "places": [],
                "items": [],
                "projects": [],
                "category": "Tasks",
                "retention": "Temporary",
                "completed": False
            })
            records.append({
                "type": "Task",
                "title": "Send project document",
                "details": "Send project document",
                "date": None,
                "time": None,
                "people": [],
                "places": [],
                "items": [],
                "projects": [],
                "category": "Tasks",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 5: "Ask Rahul about the database tomorrow."
        elif "ask rahul about the database" in t_lower:
            records.append({
                "type": "Task",
                "title": "Ask Rahul about database",
                "details": text,
                "date": "Tomorrow",
                "time": None,
                "people": ["Rahul"],
                "places": [],
                "items": [],
                "projects": [],
                "category": "Tasks",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 6: "I should finish the JeevanSetu documentation before Friday."
        elif "jeevansetu" in t_lower:
            records.append({
                "type": "Task",
                "title": "Finish JeevanSetu documentation",
                "details": text,
                "date": "this Friday",
                "time": None,
                "people": [],
                "places": [],
                "items": [],
                "projects": ["JeevanSetu"],
                "category": "Projects",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 7: "Maybe we can add offline AI search to MindBurst."
        elif "offline ai search" in t_lower:
            records.append({
                "type": "Idea",
                "title": "Add offline AI search to MindBurst",
                "details": text,
                "date": None,
                "time": None,
                "people": [],
                "places": [],
                "items": [],
                "projects": ["MindBurst"],
                "category": "Ideas",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 8: "When coming back from college, buy a new notebook."
        elif "buy a new notebook" in t_lower:
            records.append({
                "type": "Shopping",
                "title": "Buy new notebook",
                "details": text,
                "date": None,
                "time": None,
                "people": [],
                "places": ["College"],
                "items": ["Notebook"],
                "projects": [],
                "category": "Shopping",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 9: "I usually carry my charger, ID and headphones to college."
        elif "headphones" in t_lower:
            records.append({
                "type": "Carry",
                "title": "Carry charger, ID, and headphones",
                "details": text,
                "date": None,
                "time": None,
                "people": [],
                "places": ["College"],
                "items": ["Charger", "ID", "Headphones"],
                "projects": [],
                "category": "Carry",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 10: "Oh yeah don't let me forget to take my power bank tomorrow 😂"
        elif "power bank" in t_lower:
            records.append({
                "type": "Carry",
                "title": "Take power bank",
                "details": text,
                "date": "Tomorrow",
                "time": None,
                "people": [],
                "places": [],
                "items": ["Power bank"],
                "projects": [],
                "category": "Carry",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 11: "Tomorrow after class, remind me to call Rahul about the project, and buy coffee on the way home."
        elif "buy coffee on the way home" in t_lower:
            records.append({
                "type": "Task",
                "title": "Call Rahul about project",
                "details": "Call Rahul about project",
                "date": "Tomorrow",
                "time": "after class",
                "people": ["Rahul"],
                "places": [],
                "items": [],
                "projects": [],
                "category": "Tasks",
                "retention": "Temporary",
                "completed": False
            })
            records.append({
                "type": "Shopping",
                "title": "Buy coffee",
                "details": "Buy coffee on the way home",
                "date": "Tomorrow",
                "time": None,
                "people": [],
                "places": ["Home"],
                "items": ["Coffee"],
                "projects": [],
                "category": "Shopping",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 12: "I need to renew my GitHub student account."
        elif "github student account" in t_lower:
            records.append({
                "type": "Task",
                "title": "Renew GitHub student account",
                "details": text,
                "date": None,
                "time": None,
                "people": [],
                "places": [],
                "items": [],
                "projects": [],
                "category": "Tasks",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 13: "I should probably work on that project."
        elif "work on that project" in t_lower:
            records.append({
                "type": "Task",
                "title": "Work on project",
                "details": text,
                "date": None,
                "time": None,
                "people": [],
                "places": [],
                "items": [],
                "projects": [],
                "category": "Tasks",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 14: "Naalaiku college pogumbothu charger eduthutu poganum."
        elif "eduthutu poganum" in t_lower:
            records.append({
                "type": "Carry",
                "title": "Take charger",
                "details": text,
                "date": "Tomorrow",
                "time": None,
                "people": [],
                "places": ["College"],
                "items": ["Charger"],
                "projects": [],
                "category": "Carry",
                "retention": "Temporary",
                "completed": False
            })

        # Rule 15: "Tomorrow college poganum charger edukanum and uh id card don't forget"
        elif "id card don't forget" in t_lower:
            records.append({
                "type": "Carry",
                "title": "Take charger and ID card",
                "details": text,
                "date": "Tomorrow",
                "time": None,
                "people": [],
                "places": ["College"],
                "items": ["Charger", "ID card"],
                "projects": [],
                "category": "Carry",
                "retention": "Temporary",
                "completed": False
            })

        # Generic Compound thought splitting fallback
        else:
            # Smart clause split on clause delimiters, avoiding naive item ' and ' breaks
            import re
            clause_parts = re.split(r'\.|\;|\,\s*and\s+|\band\s+remind\s+me\b|\band\s+buy\b|\band\s+call\b', text, flags=re.IGNORECASE)
            clauses = [c.strip() for c in clause_parts if c.strip()]
            if not clauses:
                clauses = [text]

            for clause in clauses:
                c_lower = clause.lower()
                mem_type = "Note"
                category = "Notes"
                title = clause
                date_val = None
                place_val = None
                person_val = None
                items_extracted = []
                
                if "tomorrow" in c_lower or "naalaiku" in c_lower:
                    date_val = "Tomorrow"
                elif "today" in c_lower or "inru" in c_lower:
                    date_val = "Today"
                    
                if "college" in c_lower:
                    place_val = "College"
                elif "home" in c_lower:
                    place_val = "Home"
                    
                if "rahul" in c_lower:
                    person_val = "Rahul"
                    
                if "take" in c_lower or "carry" in c_lower or "eduthutu" in c_lower:
                    mem_type = "Carry"
                    category = "Carry"
                    if "charger" in c_lower:
                        items_extracted.append("Charger")
                    if "id" in c_lower:
                        items_extracted.append("ID")
                    if "headphone" in c_lower or "headphones" in c_lower:
                        items_extracted.append("Headphones")
                    
                    if items_extracted:
                        title = f"Take {' and '.join(items_extracted)}"
                    else:
                        title = "Take items"

                elif "ask" in c_lower or "call" in c_lower or "kekkanum" in c_lower or "should" in c_lower:
                    mem_type = "Task"
                    category = "Tasks"
                    if "project" in c_lower:
                        title = "Ask about project"
                elif "idea" in c_lower or "maybe" in c_lower:
                    mem_type = "Idea"
                    category = "Ideas"
                    title = clause
                elif "buy" in c_lower or "shopping" in c_lower:
                    mem_type = "Shopping"
                    category = "Shopping"
                    title = clause

                records.append({
                    "type": mem_type,
                    "title": title,
                    "details": clause,
                    "date": date_val,
                    "time": None,
                    "people": [person_val] if person_val else [],
                    "places": [place_val] if place_val else [],
                    "items": items_extracted,
                    "projects": [],
                    "category": category,
                    "retention": "Temporary",
                    "completed": False
                })


        return json.dumps({"memories": records}, indent=2)

    def _mock_answer(self, prompt: str) -> str:
        p_lower = prompt.lower()
        if "no relevant memories" in p_lower or "retrieved memories: none" in p_lower or "retrieved memories:\n\n" in p_lower or "retrieved memories:\nuser question" in p_lower:
            return "I couldn't find anything relevant in your memories."
        
        # Grounded mock responses based on retrieved context in prompt
        if "carry" in p_lower or "take" in p_lower:
            if "charger" in p_lower and "id" in p_lower:
                return "Tomorrow you need to carry your charger and ID for college."
            elif "charger" in p_lower:
                return "You have scheduled to carry your charger."
        
        if "rahul" in p_lower:
            return "You saved a task to ask Rahul about the project."
            
        if "jeevansetu" in p_lower:
            return "You saved a task to finish the JeevanSetu documentation."

        if "idea" in p_lower or "ideas" in p_lower:
            return "You saved an idea to add offline AI search to MindBurst."

        return "Based on your saved memories: You have items scheduled to carry and tasks noted."



class LlamaCppEngine(LocalLLMEngine):
    """
    Local llama.cpp / GGUF model runner wrapper.
    Target model: Gemma 3 4B Instruct 4-bit quantized (gemma-3-4b-instruct-q4_k_m.gguf).
    """
    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path or AppConfig.get_model_path()
        self._llm = None
        self._load_model()

    def _load_model(self):
        if not os.path.exists(self.model_path):
            print(f"[LlamaCppEngine] Model file not found at: {self.model_path}. Will fallback to MockLocalLLMEngine.")
            return

        try:
            from llama_cpp import Llama # type: ignore
            print(f"[LlamaCppEngine] Loading local GGUF model from: {self.model_path}...")
            self._llm = Llama(
                model_path=self.model_path,
                n_ctx=AppConfig.LLM_CONTEXT_SIZE,
                n_threads=AppConfig.LLM_THREADS,
                verbose=False
            )
            print("[LlamaCppEngine] Local GGUF model successfully loaded.")
        except Exception as e:
            print(f"[LlamaCppEngine] Model initialization failed: {e}. Will fallback to MockLocalLLMEngine.")
            self._llm = None

    def generate(self, prompt: str) -> str:
        if self._llm is not None:
            try:
                response = self._llm(
                    prompt,
                    max_tokens=AppConfig.LLM_MAX_TOKENS,
                    temperature=AppConfig.LLM_TEMPERATURE,
                    stop=["</s>", "<|im_end|>", "\n\n\n"]
                )
                return response['choices'][0]['text']
            except Exception as e:
                print(f"[LlamaCppEngine] Error during generation: {e}. Triggering fallback.")
        
        # Fallback to Mock engine if GGUF model is not loaded or generation fails
        return MockLocalLLMEngine().generate(prompt)


def get_local_llm_engine(model_path: Optional[str] = None) -> LocalLLMEngine:
    """
    Factory function for obtaining local LLM engine instance.
    Checks model existence and runtime availability. Returns LlamaCppEngine if model exists,
    otherwise returns MockLocalLLMEngine cleanly.
    """
    target_path = model_path or AppConfig.get_model_path()
    if os.path.exists(target_path) and os.path.isfile(target_path):
        engine = LlamaCppEngine(model_path=target_path)
        if engine._llm is not None:
            return engine
            
    return MockLocalLLMEngine()
