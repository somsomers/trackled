# Trackled — сценарии сборки
# Запуск: `just <рецепт>`; без аргумента показывает список.

app_name := "Trackled"
bundle   := "build/" + app_name + ".app"
apps_dir := env_var('HOME') / "Applications"

# Список доступных рецептов
default:
    @just --list

# Просто сборка release-бинарника (SwiftPM)
build:
    swift build -c release

# Сборка + упаковка в .app-бандл (build/Trackled.app)
bundle:
    ./make_app.sh

# Сборка + бандл + деплой в ~/Applications
deploy: bundle
    mkdir -p "{{apps_dir}}"
    rm -rf "{{apps_dir}}/{{app_name}}.app"
    cp -R "{{bundle}}" "{{apps_dir}}/"
    @echo "==> Установлено: {{apps_dir}}/{{app_name}}.app"

# Запустить установленный бандл
run: bundle
    open "{{bundle}}"

# Удалить артефакты сборки
clean:
    rm -rf .build build
