"""
MindBurst — Root Application Entrypoint for Buildozer / Android
"""
import os
import sys

# Ensure current directory and mindburst package are in sys.path
root_dir = os.path.dirname(os.path.abspath(__file__))
if root_dir not in sys.path:
    sys.path.insert(0, root_dir)

from mindburst.main import main

if __name__ == "__main__":
    main()
