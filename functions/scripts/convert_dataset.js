const fs = require('fs');

const inputFile = 'bhrigu_chat_dataset.jsonl';
const outputFile = 'bhrigu_chat_dataset_vertex.jsonl';

const lines = fs.readFileSync(inputFile, 'utf8').split('\n').filter(line => line.trim() !== '');
const newLines = [];

for (const line of lines) {
  try {
    const j = JSON.parse(line);
    
    const systemMsg = j.messages.find(m => m.role === 'system');
    const userMsg = j.messages.find(m => m.role === 'user');
    const modelMsg = j.messages.find(m => m.role === 'model' || m.role === 'assistant');

    if (!userMsg || !modelMsg) continue;

    const newJ = {
      contents: [
        {
          role: 'user',
          parts: [{ text: userMsg.content }]
        },
        {
          role: 'model',
          parts: [{ text: modelMsg.content }]
        }
      ]
    };

    if (systemMsg) {
      newJ.systemInstruction = {
        role: 'system',
        parts: [{ text: systemMsg.content }]
      };
    }

    newLines.push(JSON.stringify(newJ));
  } catch (e) {
    console.error('Failed to parse line', e.message);
  }
}

fs.writeFileSync(outputFile, newLines.join('\n'));
console.log(`Successfully converted ${newLines.length} examples to Vertex AI format!`);
console.log(`Saved to: ${outputFile}`);
