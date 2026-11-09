import subprocess
import re
import os
import sys

FLUTTER_CMD = r"C:\Users\bhavv\flutter\bin\flutter.bat"
APP_DIR = r"c:\Users\bhavv\OneDrive\Desktop\Dravvya(4th Sem)\Projects\Bit_Loggers\bit_loggers_app"

def run_analyze(rel_path=""):
    target = f"lib/{rel_path}".replace("//", "/") if rel_path else ""
    cmd = [FLUTTER_CMD, "analyze"]
    if target:
        cmd.append(target)
    proc = subprocess.run(cmd, cwd=APP_DIR, capture_output=True, text=True)
    return proc.stdout

def fix_file_constants(file_path):
    print(f"\n--- Checking {file_path} ---")
    for iteration in range(5):
        output = run_analyze(file_path)
        
        # Collect line numbers for constant errors
        lines_to_fix = set()
        for line in output.splitlines():
            m = re.search(r"error - .*? - (lib\\[^:]+):(\d+):(\d+) - (invalid_constant|non_constant_list_element|const_initialized_with_non_constant_value|non_constant_map_value|const_with_non_constant_argument)", line)
            if m:
                lines_to_fix.add(int(m.group(2)))
        
        if not lines_to_fix:
            print(f"Clean! No constant issues in {file_path}")
            break
            
        print(f"Iteration {iteration + 1}: Found {len(lines_to_fix)} error lines")
        
        full_path = os.path.join(APP_DIR, "lib", file_path.replace("/", "\\"))
        with open(full_path, "r", encoding="utf-8") as f:
            src_lines = f.readlines()
            
        # Process from bottom to top so line shifts don't mess up indices
        for lno in sorted(lines_to_fix, reverse=True):
            idx = lno - 1
            if idx >= len(src_lines):
                continue
                
            # If static const Map or variable:
            if "static const " in src_lines[idx]:
                src_lines[idx] = src_lines[idx].replace("static const ", "static final ")
                continue
                
            # If const is on the current line
            if re.search(r"\bconst\s+", src_lines[idx]):
                src_lines[idx] = re.sub(r"\bconst\s+", "", src_lines[idx], count=1)
                continue
                
            # Search backwards up to 10 lines
            found = False
            for back in range(1, 12):
                up_idx = idx - back
                if up_idx < 0:
                    break
                # Only check within same indentation or higher
                if re.search(r"\bconst\s+", src_lines[up_idx]):
                    src_lines[up_idx] = re.sub(r"\bconst\s+", "", src_lines[up_idx], count=1)
                    found = True
                    break
                    
        with open(full_path, "w", encoding="utf-8") as f:
            f.writelines(src_lines)

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else ""
    if target:
        fix_file_constants(target)
    else:
        # Check all screen files
        files = [
            "screens/calendar_screen.dart",
            "screens/kanban_screen.dart",
            "screens/analytics_screen.dart",
            "screens/audit_screen.dart",
            "screens/campaign_detail_screen.dart",
            "screens/campaign_wizard_screen.dart",
            "screens/diagnostics_screen.dart",
            "screens/gemini_argon_screen.dart",
            "screens/notifications_screen.dart",
            "screens/sync_hub_screen.dart",
            "screens/test_runner_screen.dart",
            "widgets/marketing_visuals.dart",
        ]
        for f in files:
            fix_file_constants(f)
