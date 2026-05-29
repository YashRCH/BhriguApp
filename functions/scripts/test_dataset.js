const fs = require('fs');
const content = fs.readFileSync('bhrigu_chat_dataset.jsonl', 'utf8');
const parts = content.split('{"messages"');
for(let i=1; i<=5; i++) {
  const part = '{"messages"' + parts[i].substring(0, parts[i].lastIndexOf('}') + 1);
  try {
    const json = JSON.parse(part);
    console.log(`EX ${i} - Length: ${json.messages[2].content.length}, Words: ${json.messages[2].content.split(' ').length}`);
    console.log(json.messages[2].content.substring(0, 50) + ' ... ' + json.messages[2].content.slice(-50));
  } catch(e) {
    console.log('Error parsing', i);
  }
}
