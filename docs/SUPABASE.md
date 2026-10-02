# Supabase и аутентификация

## MCP

В проект подключён Supabase MCP. Базовая миграция каталога уже применена к
удалённому проекту; дополнительная миграция hardening добавляет ограничения
workflow и таблицу установленных модулей.

Перед следующими изменениями нужно проверять таблицы, миграции и advisories.
Миграции находятся в `supabase/migrations/` и применяются в том же порядке.
Production следует обновлять только после проверки RLS и Edge Functions.

## Auth providers

В Supabase Dashboard → Authentication → Providers включить:

- Email — email/password, подтверждение email и reset password;
- Google OAuth — Client ID/Secret и callback URL Supabase;
- GitHub OAuth — Client ID/Secret и callback URL Supabase.

Таблицы и Auth trigger уже установлены. Для GitHub владелец проекта создал OAuth
приложение и добавил credentials в Supabase Dashboard. Client Secret хранится
только в Supabase и не должен попадать в репозиторий или desktop-клиент.

Для текущего проекта callback URL Supabase:
`https://egqzeqlenafpnziplxgb.supabase.co/auth/v1/callback`.
Его нужно указать как **Authorization callback URL** при создании GitHub OAuth
App. Затем Client ID/Secret вносятся в Supabase Dashboard → Authentication →
Sign In / Providers → GitHub, где provider включается.

В Supabase → Authentication → URL Configuration добавить
`qualia-engine://auth/callback` в Redirect URLs. Linux desktop manifest
регистрирует `x-scheme-handler/qualia-engine`; после установки Linux-пакета
зарегистрируйте desktop-файл в окружении пользователя, если пакетный менеджер
не сделал это автоматически (`update-desktop-database ~/.local/share/applications`).
Flutter открывает браузер через Supabase Auth PKCE flow и принимает возврат через
`app_links`. Клиент использует только publishable key из
`app/lib/core/auth/supabase_config.dart` или `--dart-define`; service role key
никогда не попадает во Flutter/AppImage.

## Безопасность

- `auth.users` хранит credentials и OAuth identities;
- `public.profiles` хранит только отображаемое имя и avatar URL;
- при первом создании auth-пользователя профиль также получает публичный
  `username` из `user_name`/`preferred_username` (GitHub OAuth); повторные
  OAuth-идентичности хранятся только в `auth.identities`;
- module package bucket приватный;
- `public.module_installations` хранит выбранный published release, enabled и
  выданные capabilities для конкретного пользователя;
- signed download URLs выдаются только для опубликованных и совместимых
  releases;
- публикация system modules и смена review state на published выполняются только
  серверным trusted service;
- прямой EXECUTE-доступ к trigger-функциям закрыт для `anon` и
  `authenticated`.
