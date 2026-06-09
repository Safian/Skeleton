#!/bin/bash
# Elküldi a flutter3_cleanup_plan.md tervet a lokális MLX modellnek (OpenAI-kompatibilis API)
# Modell: mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit, port: 8080

PLAN_FILE="$(dirname "$0")/flutter3_cleanup_plan.md"
MODEL="mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit"
URL="http://localhost:8080/v1/chat/completions"

PLAN_CONTENT="$(cat "$PLAN_FILE")"

PROMPT="A következő implementációs tervet kell végrehajtanod egy Flutter projektben (Skeleton + KibbiAi). Kérlek, dolgozd fel a tervet, és add meg, hogy milyen konkrét shell parancsokat / fájlmódosításokat hajtanál végre az egyes lépések teljesítéséhez:

${PLAN_CONTENT}"

jq -n --arg model "$MODEL" --arg prompt "$PROMPT" \
  '{model: $model, messages: [{role: "user", content: $prompt}], temperature: 0.2}' \
  | curl -s "$URL" -H "Content-Type: application/json" -d @- | jq -r '.choices[0].message.content'
