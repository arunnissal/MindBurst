"""
App Configuration Management for MindBurst
Isolates model paths, context settings, and runtime configurations.
"""
import os
from mindburst.utils.helpers import get_app_dir

class AppConfig:
    # Model configuration
    DEFAULT_MODEL_NAME = "gemma-3-4b-instruct-q4_k_m.gguf"
    
    @classmethod
    def get_model_path(cls) -> str:
        """
        Returns GGUF model file path.
        Priority:
        1. Environment variable MINDBURST_MODEL_PATH
        2. App data models directory (~/.mindburst/models/gemma-3-4b-instruct-q4_k_m.gguf)
        """
        env_path = os.environ.get("MINDBURST_MODEL_PATH")
        if env_path and env_path.strip():
            return env_path.strip()
        
        return os.path.join(get_app_dir(), "models", cls.DEFAULT_MODEL_NAME)

    @classmethod
    def is_model_file_present(cls) -> bool:
        """Returns True if the GGUF model file exists on local disk."""
        path = cls.get_model_path()
        return os.path.exists(path) and os.path.isfile(path)

    # LLM Runtime settings
    LLM_CONTEXT_SIZE = int(os.environ.get("MINDBURST_LLM_CTX", "2048"))
    LLM_THREADS = int(os.environ.get("MINDBURST_LLM_THREADS", "4"))
    LLM_MAX_TOKENS = int(os.environ.get("MINDBURST_LLM_MAX_TOKENS", "512"))
    LLM_TEMPERATURE = float(os.environ.get("MINDBURST_LLM_TEMP", "0.1"))
