defmodule OneBackupRestoreWeb.FlexBar.Tab.Upload do
  @moduledoc """
  Backup Upload Flex Tab.
  """
  use OneChatWeb.FlexBar.Helpers
  use OneLogger

  alias InfinityOne.{TabBar.Tab}
  alias InfinityOne.{TabBar}
  alias OneBackupRestoreWeb.FlexBarView
  alias OneBackupRestore.Backup
  alias OneUiFlexTab.FlexTabChannel, as: Channel

  @doc """
  Add the Backup Upload tab to the Flex Tabs list
  """
  @spec add_buttons() :: no_return
  def add_buttons do
    TabBar.add_button Tab.new(
      __MODULE__,
      ~w[admin_backup_restore],
      "admin_upload_backup",
      ~g"Upload",
      "icon-upload",
      FlexBarView,
      "upload.html",
      15,
      [
        model: Backup,
        prefix: "backup"
      ]
    )
  end

  @doc """
  Callback for the rendering bindings for the Upload panel.
  """
  def args(socket, {user_id, _channel_id, _, _sender}, _params) do
    current_user = Helpers.get_user! user_id

    {[
      current_user: current_user,
      changeset: Backup.change(),
    ], socket}
  end

  @doc """
  Handle the cancel button.
  """
  def flex_form_cancel(socket, sender) do
    socket
    |> Channel.flex_close(sender)
  end
end

