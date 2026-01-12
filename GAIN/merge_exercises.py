import json
import shutil

# Files
EXERCISES_FILE = 'exercises.json'
NEW_EXERCISES_FILE = 'new_exercises.json'

def merge_exercises():
    try:
        # Read existing exercises
        try:
            with open(EXERCISES_FILE, 'r') as f:
                existing_data = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            existing_data = []

        # Map existing exercises by name for easy update
        exercise_map = {ex['name']: ex for ex in existing_data}

        # Read new exercises
        with open(NEW_EXERCISES_FILE, 'r') as f:
            new_data = json.load(f)

        # Merge
        added_count = 0
        updated_count = 0
        
        for new_ex in new_data:
            name = new_ex['name']
            if name in exercise_map:
                # Update existing (overwrite details)
                # Keep keys that might exist in old but not new?
                # User provided data seems comprehensive, so we can overwrite or merge keys.
                # Let's overwrite fields present in new_ex
                exercise_map[name].update(new_ex)
                updated_count += 1
            else:
                # Add new
                existing_data.append(new_ex)
                exercise_map[name] = new_ex # Update map just in case
                added_count += 1

        # Write back
        # Backup first
        shutil.copy2(EXERCISES_FILE, EXERCISES_FILE + '.bak')
        
        with open(EXERCISES_FILE, 'w') as f:
            json.dump(existing_data, f, indent=2)
            
        print(f"Merge successful. Added: {added_count}, Updated: {updated_count}")

    except Exception as e:
        print(f"Error merging exercises: {e}")

if __name__ == "__main__":
    merge_exercises()
