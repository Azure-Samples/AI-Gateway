# to run locally, use the following command in the root folder of the repository:python .github/workflows/nbchecks.py

import json, sys, os
from pathlib import Path

def has_outputs_stored(file):
    with open(file, 'r', encoding='utf-8') as f:
        notebook_content = json.load(f)
    
    for cell in notebook_content.get('cells', []):
        if cell.get('cell_type') == 'code' and cell.get('outputs'):
            print(f"The notebook {filename} has outputs stored.", file=sys.stderr)
            return True
    return False

exit_code = 0
for file in Path(".").glob('**/*.ipynb'):
    filename = os.fsdecode(file)
    if has_outputs_stored(file):        
        exit_code = 1
if exit_code == 0:
    print("All good. No stored output found.")
sys.exit(exit_code)