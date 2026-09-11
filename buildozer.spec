[app]

# (str) Title of your application
title = MindBurst

# (str) Package name
package.name = mindburst

# (str) Package domain (needed for android/ios packaging)
package.domain = org.mindburst

# (str) Source code where the main.py live
source.dir = .

# (list) Source files to include (let empty to include all the base dir)
source.include_exts = py,png,jpg,kv,atlas,json,db,gguf,txt,ttf

# (list) List of directory to exclude (let empty to not exclude anything)
source.exclude_dirs = tests, bin, .venv, .git, .pytest_cache

# (str) Application versioning (method 1)
version = 1.0.0

# (list) Application requirements
# comma separated e.g. requirements = sqlite3,kivy
requirements = python3, kivy, https://github.com/kivymd/KivyMD/archive/master.zip, pillow, materialyoucolor, materialshapes, asynckivy, asyncgui, exceptiongroup, android, pyjnius, requests, urllib3

# (str) Custom source folders for requirements
# (list) Permissions
permissions = RECORD_AUDIO,INTERNET

# (str) Supported orientation (one of landscape, sensorLandscape, portrait or all)
orientation = portrait

# (bool) Indicate if the application should be fullscreen or not
fullscreen = 0

# (str) Preserved Android NDK / SDK settings
android.minapi = 24
android.api = 34
android.ndk = 25b
android.archs = arm64-v8a


# (bool) Use --private data directory (True) or --dir public storage (False)
android.private_storage = True

# (bool) Accept SDK license automatically
android.accept_sdk_license = True

# (list) List of Java .jar files to add to the libs so that pyjnius can access
# their classes. Don't add jars that you do not meanto use!!
# android.add_jars = foo.jar,bar.jar

# (str) Bootstrap to use for android (sdl2)
p4a.bootstrap = sdl2

[buildozer]

# (int) Log level (0 = error only, 1 = info, 2 = debug (with command output))
log_level = 2

# (int) Display warning if buildozer is run as root (0 = false, 1 = true)
warn_on_root = 0
