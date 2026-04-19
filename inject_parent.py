import os
import re

TARGET_DIR = '/Volumes/PRO-G40/FANZONE/lib'
IMPORT_GLASS = "import 'package:fanzone/widgets/common/fz_glass_loader.dart';\n"

# Files that need the import in their parent:
ERROR_FILES = [
    'h2h_table_predict_tabs.dart',
    'insights_tab.dart',
    'lineups_tab.dart',
    'overview_tab.dart',
    'stats_tab.dart',
    'predict_pool_create_sheet.dart',
    'predict_slips_view.dart'
]

def find_and_inject():
    for root, dirs, files in os.walk(TARGET_DIR):
        for file in files:
            if file in ERROR_FILES:
                filepath = os.path.join(root, file)
                with open(filepath, 'r') as f:
                    content = f.read()
                
                # find part of
                match = re.search(r"part of\s+['\"](.*?)['\"];", content)
                if match:
                    relative_parent = match.group(1)
                    parent_path = os.path.normpath(os.path.join(root, relative_parent))
                    
                    if os.path.exists(parent_path):
                        with open(parent_path, 'r') as pf:
                            p_content = pf.read()
                        
                        if 'fz_glass_loader.dart' not in p_content:
                            # insert import
                            lines = p_content.split('\n')
                            last_import_idx = -1
                            for i, line in enumerate(lines):
                                if line.startswith('import '):
                                    last_import_idx = i
                            if last_import_idx != -1:
                                lines.insert(last_import_idx + 1, IMPORT_GLASS.strip())
                                new_p = '\n'.join(lines)
                                with open(parent_path, 'w') as pf:
                                    pf.write(new_p)
                                print(f"Injected import into {parent_path}")

find_and_inject()
