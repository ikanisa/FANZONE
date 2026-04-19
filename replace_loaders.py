import os
import re

TARGET_DIR = '/Volumes/PRO-G40/FANZONE/lib'
IMPORT_GLASS = "import '../../widgets/common/fz_glass_loader.dart';\n"
IMPORT_GLASS_DEEP = "import '../../../widgets/common/fz_glass_loader.dart';\n"
IMPORT_SHIMMER = "import '../../widgets/common/fz_shimmer.dart';\n"
IMPORT_SHIMMER_DEEP = "import '../../../widgets/common/fz_shimmer.dart';\n"

# These files need ScoresPageSkeleton or FixtureGroupSkeleton
SHIMMER_FILES = [
    'league_hub_screen.dart',
    'match_detail_screen.dart',
    'following_screen.dart',
    'event_hub_screen.dart',
    'home_feed_screen.dart',
    'pool_detail_screen.dart',
]

def add_import(content, import_stmt):
    if import_stmt.strip() in content:
        return content
    
    # find last import
    lines = content.split('\n')
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.startswith('import '):
            last_import_idx = i
            
    if last_import_idx != -1:
        lines.insert(last_import_idx + 1, import_stmt.strip())
        return '\n'.join(lines)
    return import_stmt + content

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    if 'CircularProgressIndicator' not in content:
        return False

    filename = os.path.basename(filepath)
    depth = filepath.count('/') - TARGET_DIR.count('/')
    
    import_glass = IMPORT_GLASS_DEEP if depth > 3 else IMPORT_GLASS
    import_shimmer = IMPORT_SHIMMER_DEEP if depth > 3 else IMPORT_SHIMMER
    
    original_content = content

    if filename in SHIMMER_FILES:
        # Full page replacement
        content = re.sub(r'const Center\(child: CircularProgressIndicator\(\)\)', 'const ScoresPageSkeleton()', content)
        content = re.sub(r'const Scaffold\(body: Center\(child: CircularProgressIndicator\(\)\)\)', 'const Scaffold(body: ScoresPageSkeleton())', content)
        content = re.sub(r'Center\(child: CircularProgressIndicator\(\)\)', 'const ScoresPageSkeleton()', content)
        content = re.sub(r'CircularProgressIndicator\(\)', 'const ScoresPageSkeleton()', content)
        content = add_import(content, import_shimmer)
    else:
        # Inline replacements
        content = re.sub(r'const Center\(child: CircularProgressIndicator\(\)\)', 'const FzGlassLoader(message: \'Syncing...\')', content)
        content = re.sub(r'const Center\(child: CircularProgressIndicator\.adaptive\(\)\)', 'const FzGlassLoader(message: \'Syncing...\')', content)
        content = re.sub(r'Center\(child: CircularProgressIndicator(?:\.adaptive)?\(\)\)', 'const FzGlassLoader(message: \'Syncing...\')', content)
        content = re.sub(r'CircularProgressIndicator\(\)', 'const FzGlassLoader()', content)
        content = re.sub(r'CircularProgressIndicator\.adaptive\(\)', 'const FzGlassLoader()', content)
        content = re.sub(r'CircularProgressIndicator\(strokeWidth: \d+\.?[0-9]*\)', 'const FzGlassLoader(useBackdrop: false)', content)
        content = re.sub(r'CircularProgressIndicator\(color: [^)]+\)', 'const FzGlassLoader(useBackdrop: false)', content)
        content = add_import(content, import_glass)

    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Updated {filename}")
        return True
    return False

def main():
    count = 0
    for root, dirs, files in os.walk(TARGET_DIR):
        for file in files:
            if file.endsWith('.dart'):
                pass # Python doesn't have endsWith. Let's fix this in the main code.

if __name__ == '__main__':
    count = 0
    for root, dirs, files in os.walk(TARGET_DIR):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                if process_file(filepath):
                    count += 1
    print(f"Total files updated: {count}")
