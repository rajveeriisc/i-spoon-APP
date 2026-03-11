import glob

files = glob.glob('lib/**/*.dart', recursive=True)
for filepath in files:
    with open(filepath, 'r') as f:
        content = f.read()

    original = content
    content = content.replace("AppTheme.turquoise", "AppTheme.emerald")
    content = content.replace("AppTheme.indigo", "AppTheme.emerald")
    content = content.replace("AppTheme.sky", "AppTheme.emerald")
    
    # We must not break definitions in app_theme.dart, but those are internally just aliases.
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Updated {filepath}")
