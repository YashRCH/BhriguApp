import json
import re

input_file = r'C:\wellnesguru\astrology_guru_app\astrology_guru_app\functions\scripts\bhrigu_chat_dataset_vertex.jsonl'
output_file = r'C:\wellnesguru\astrology_guru_app\astrology_guru_app\lib\constants\random_prompts.dart'

prompts = set()
with open(input_file, 'r', encoding='utf-8') as f:
    for line in f:
        try:
            data = json.loads(line)
            text = data['contents'][0]['parts'][0]['text']
            match = re.search(r'User Query:\s*(.*?)(?=\n\n|$)', text, re.DOTALL)
            if match:
                query = match.group(1).strip()
                if query:
                    prompts.add(query)
        except Exception as e:
            continue

prompts_list = list(prompts)
prompts_list.sort()

with open(output_file, 'w', encoding='utf-8') as f:
    f.write('const List<String> randomPrompts = [\n')
    for p in prompts_list:
        escaped_p = p.replace("'", "\\'")
        f.write(f"  '{escaped_p}',\n")
    f.write('];\n')

print(f'Extracted {len(prompts_list)} prompts to {output_file}')
