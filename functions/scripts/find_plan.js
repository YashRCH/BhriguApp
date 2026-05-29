const fs = require('fs');
const lines = fs.readFileSync('C:/Users/richh/.gemini/antigravity/brain/b6f9aa71-a5ad-405f-95bb-c49f8a3baa67/.system_generated/logs/transcript.jsonl', 'utf8').split('\n');
const planSteps = lines.filter(l => l.includes('"name":"write_to_file"') && l.includes('implementation_plan.md'));
if (planSteps.length > 0) {
    const firstPlan = JSON.parse(planSteps[0]);
    console.log(JSON.stringify(firstPlan, null, 2));
} else {
    console.log("No plan found in transcript.");
}
