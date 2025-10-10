# Load secrets from pass
set -xg GEMINI_API_KEY (pass show ai/gemini_cli_mom | head -n 1)

# Сюда можно будет добавлять другие секреты в будущем
