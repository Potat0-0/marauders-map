import fs from "fs";
import path from "path";

const ROOT = process.argv[2] || ".";

// patterns with weights (higher = more suspicious)
const RULES = [
  { regex: /fromCharCode/, weight: 3 },
  { regex: /charAt\(/, weight: 2 },
  { regex: /charCodeAt\(/, weight: 2 },
  { regex: /String\.fromCharCode/, weight: 3 },
  { regex: /\beval\(/, weight: 4 },
  { regex: /\bFunction\(/, weight: 4 },
  { regex: /\.constructor\(/, weight: 4 },
  { regex: /atob\(|btoa\(/, weight: 2 },
  { regex: /\\x[0-9a-fA-F]{2}/, weight: 2 },   // hex encoding
  { regex: /\\u[0-9a-fA-F]{4}/, weight: 2 },   // unicode encoding
  { regex: /[A-Za-z0-9+/]{80,}={0,2}/, weight: 3 }, // base64-ish long strings
];

// threshold to report
const THRESHOLD = 4;

// ignore dirs
const IGNORE_DIRS = new Set([
  "node_modules", ".git", "dist", "build", "coverage"
]);

function scanFile(filePath) {
  let content;
  try {
    content = fs.readFileSync(filePath, "utf8");
  } catch {
    return; // skip binary/unreadable
  }

  const lines = content.split("\n");

  lines.forEach((line, i) => {
    let score = 0;
    let matches = [];

    for (const rule of RULES) {
      if (rule.regex.test(line)) {
        score += rule.weight;
        matches.push(rule.regex.source);
      }
    }

    // extra heuristic: very long line
    if (line.length > 300) {
      score += 2;
      matches.push("long_line");
    }

    if (score >= THRESHOLD) {
      console.log(
        `${filePath}:${i + 1} [score=${score}] -> }`
      );
    }
  });
}

function walk(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    if (IGNORE_DIRS.has(entry.name)) continue;

    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      walk(fullPath);
    } else {
      scanFile(fullPath);
    }
  }
}

walk(ROOT);