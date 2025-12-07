# # Функция для загрузки секрета (без кэширования)
# function load_secret
#     set -l var_name $argv[1]
#     set -l pass_path $argv[2]
#     set -l transform $argv[3..-1]
#     if not set -q $var_name
#         if test -n "$transform"
#             set -gx $var_name (pass show $pass_path | eval $transform)
#         else
#             set -gx $var_name (pass show $pass_path)
#         end
#     end
# end
#
# Функция для загрузки секрета (без кэширования)
function load_secret
    set -l var_name $argv[1]
    set -l pass_path $argv[2]
    set -l transform $argv[3..-1]
    if not set -q $var_name
        if test -n "$transform"
            # ИСПРАВЛЕНИЕ: eval теперь выполняет всю команду целиком
            set -gx $var_name (eval "pass show $pass_path | $transform")
        else
            set -gx $var_name (pass show $pass_path)
        end
    end
end
# Загружаем секреты ТОЛЬКО если это интерактивный терминал
if status is-interactive
    load_secret GEMINI_API_KEY ai/gemini_cli_mom "head -n 1"
    load_secret GEMINI_EMAIL ai/gemini_cli_mom "grep 'email:' | string replace 'email: ' ''"
    load_secret GOOGLE_CLOUD_PROJECT ai/gemini_cli_mom "grep 'project_id:' | string replace 'project_id: ' ''"
end
