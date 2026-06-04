import os
import re

out = []
for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                classes = re.findall(r'class\s+(\w+)', content)
                functions = re.findall(r'(?:[\w<>,\s]+)\s+(\w+)\s*\(.*?\)\s*(?:{|async)', content)
                functions = [f for f in functions if f not in ['if', 'for', 'while', 'switch', 'catch', 'return']]
                out.append(f'## File: {filepath}')
                out.append(f'- **Classes:** {", ".join(classes) if classes else "None"}')
                out.append(f'- **Methods/Functions:** {", ".join(functions[:20]) if functions else "None"}')
                out.append('')

with open('lib_overview.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))
