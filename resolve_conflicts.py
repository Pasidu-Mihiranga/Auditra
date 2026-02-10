
import os
import sys

def resolve_file(file_path):
    print(f"Resolving {file_path}...")
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return

    new_lines = []
    in_conflict = False
    keeping = False # True when we are in the HEAD part
    
    conflict_count = 0

    for line in lines:
        stripped = line.strip()
        if stripped.startswith('<<<<<<< HEAD'):
            in_conflict = True
            keeping = True
            conflict_count += 1
            continue
        
        if in_conflict and stripped.startswith('======='):
            keeping = False
            continue
            
        if in_conflict and stripped.startswith('>>>>>>>'):
            in_conflict = False
            keeping = False
            continue

        if in_conflict:
            if keeping:
                new_lines.append(line)
        else:
            new_lines.append(line)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print(f"Resolved {conflict_count} conflicts in {file_path}.")

if __name__ == "__main__":
    files = [
        r"c:\Users\PMIHIR\Desktop\Software project\#New\Auditra 2\Auditra\auditra\lib\screens\create_project_screen.dart"
    ]
    
    for f in files:
        if os.path.exists(f):
            resolve_file(f)
        else:
            print(f"File not found: {f}")
