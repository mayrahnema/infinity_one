defmodule UccChat.Web.AccountView do
  use UccChat.Web, :view

  def allow_delete_own_account, do: true
  def allow_password_change, do: true
  def allow_email_change, do: true
  def email_verified, do: true
  def allow_username_change, do: true

  def desktop_notification_duration, do: true
  def desktop_notification_disabled, do: false
  def desktop_notification_enabled, do: true
  def get_languages do
    [{~g"English", "en"}]
  end

  def radio_button_line(f, id, title, field, schema, opts \\ []) do
    {label_on, label_off} = opts[:labels] || {~g"True", ~g"False"}
    class = opts[:class] || "double-col"
    desc = opts[:description]
    "radio_button_line.html"
    |> render([f: f, id: id, title: title, field: field, schema: schema,
      class: class, desc: desc, on: label_on, off: label_off])
    |> Phoenix.HTML.raw
  end
end
