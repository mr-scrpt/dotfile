# --- Gemini CLI Secrets ---

# 1. Получаем API ключ (берем первую строку)
set -xg GEMINI_API_KEY (pass show ai/gemini_cli_mom | head -n 1)

# 2. Получаем ID проекта
#    (ищем строку с 'project_id:', а затем забираем все, что идет после ': ')
set -xg GOOGLE_CLOUD_PROJECT (pass show ai/gemini_cli_mom | grep 'project_id:' | awk -F': ' '{print $2}')
