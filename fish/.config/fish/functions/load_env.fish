# Функция для загрузки переменных из .env файла
function load_env --description 'Load environment variables from .env file'
    set env_file ~/.config/fish/.env

    if test -f $env_file
        for line in (cat $env_file | grep -v '^#' | grep -v '^$')
            set -l key_value (string split -m 1 '=' $line)
            if test (count $key_value) -eq 2
                set -gx $key_value[1] $key_value[2]
                # echo "Loaded: $key_value[1]"
            end
        end
    else
        echo "Warning: .env file not found at $env_file"
    end
end

# Автоматически загружаем .env при старте fish
load_env
