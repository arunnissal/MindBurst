"""
Phase 5 Automated Test Suite — Real Local LLM Integration & Engine Fallback
Tests:
1. Configurable GGUF model path (AppConfig and MINDBURST_MODEL_PATH)
2. Model file presence detection (is_model_file_present)
3. Engine factory (get_local_llm_engine) fallback behavior
4. LlamaCppEngine interface compliance (subclass of LocalLLMEngine)
5. LlamaCppEngine runtime error/missing model graceful fallback to MockLocalLLMEngine
"""
import os
import tempfile
import pytest

from mindburst.utils.config import AppConfig
from mindburst.ai.llm_engine import LocalLLMEngine, MockLocalLLMEngine, LlamaCppEngine, get_local_llm_engine

def test_configurable_model_path_env():
    """Verify that MINDBURST_MODEL_PATH environment variable overrides default model path."""
    original_env = os.environ.get("MINDBURST_MODEL_PATH")
    try:
        custom_path = "C:\\custom\\models\\gemma-3-4b-instruct.gguf"
        os.environ["MINDBURST_MODEL_PATH"] = custom_path
        
        assert AppConfig.get_model_path() == custom_path
    finally:
        if original_env is None:
            os.environ.pop("MINDBURST_MODEL_PATH", None)
        else:
            os.environ["MINDBURST_MODEL_PATH"] = original_env


def test_model_presence_detection():
    """Verify is_model_file_present returns False when GGUF file is absent."""
    original_env = os.environ.get("MINDBURST_MODEL_PATH")
    try:
        os.environ["MINDBURST_MODEL_PATH"] = "C:\\nonexistent\\model.gguf"
        assert AppConfig.is_model_file_present() is False
    finally:
        if original_env is None:
            os.environ.pop("MINDBURST_MODEL_PATH", None)
        else:
            os.environ["MINDBURST_MODEL_PATH"] = original_env


def test_llm_engine_factory_fallback():
    """Verify get_local_llm_engine returns MockLocalLLMEngine when GGUF model is not present."""
    engine = get_local_llm_engine(model_path="C:\\nonexistent\\model.gguf")
    assert isinstance(engine, LocalLLMEngine)
    assert isinstance(engine, MockLocalLLMEngine)


def test_llama_cpp_engine_interface_compliance():
    """Verify LlamaCppEngine satisfies LocalLLMEngine abstract interface."""
    assert issubclass(LlamaCppEngine, LocalLLMEngine)
    
    # Instantiate with non-existent path
    engine = LlamaCppEngine(model_path="C:\\nonexistent\\model.gguf")
    assert engine._llm is None
    
    # Ensure generate calls fallback without throwing exception
    res = engine.generate("Input: \"Tomorrow college pogumbothu charger eduthutu poganum\"\nOutput:")
    assert isinstance(res, str)
    assert len(res) > 0
