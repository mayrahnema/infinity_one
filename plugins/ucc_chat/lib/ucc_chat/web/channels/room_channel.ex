defmodule UccChat.Web.RoomChannel do
  @moduledoc """
  Handle incoming and outgoing Subscription messages
  """
  use UccChat.Web, :channel
  use UccLogger

  use Rebel.Channel, name: "room", controllers: [
    UccChat.Web.ChannelController,
  ], intercepts: [
    "user:action",
    "room:state_change",
    "room:update:list",
    "room:delete"
  ]

  alias UccChat.{Subscription, Channel, Message}
  alias UccChat.{Web.UserSocket}
  alias UccChat.ServiceHelpers, as: Helpers
  alias UcxUcc.Permissions
  alias UcxUcc.Web.Endpoint

  require UccChat.ChatConstants, as: CC

  ############
  # API

  def user_join(nil), do: Logger.warn "join for nil username"
  def user_join(username, room) do
    # Logger.warn "user_join username: #{inspect username}, room: #{inspect room}"
    Endpoint.broadcast CC.chan_room <> room, "user:join", %{username: username}
  end

  def user_leave(nil), do: Logger.warn "leave for nil username"
  def user_leave(username, room) do
    Logger.warn "user_leave username: #{inspect username}, room: #{inspect room}"
    Endpoint.broadcast CC.chan_room <> room, "user:leave", %{username: username}
  end

  ############
  # Socket stuff

  def join(ev = CC.chan_room <> "lobby", msg, socket) do
    Logger.info "user joined lobby msg: #{inspect msg}, socket: #{inspect socket}"
    super ev, msg, socket
    # {:ok, socket}
  end

  def join(ev = CC.chan_room <> room, msg, socket) do
    trace ev, msg
    send self(), {:after_join, room, msg}
    super ev, msg, socket
    # {:ok, socket}
  end

  def topic(_broadcasting, _controller, _request_path, conn_assigns) do
    conn_assigns.chatd.active_room.name
  end

  def handle_info({:after_join, room, msg}, socket) do
    # room = String.split(room, "/") |> List.last
    trace room, msg
    channel = Channel.get_by!(name: room)
    broadcast! socket, "user:entered", %{user: msg["user"],
      channel_id: channel.id}
    push socket, "join", %{status: "connected"}
    # UserSocket.push_message_box socket, socket.assigns.user_id, channel.id
    # ChannelService.clear_unread(channel.id, socket.assigns.user_id)
    # socket = Phoenix.Socket.assign(socket, :user_id, msg["user_id"])
    {:noreply, socket}
  end

  ##########
  # Outgoing message handlers

  def handle_out(ev = "room:state_change", msg, %{assigns: assigns} = socket) do
    debug ev, msg, "assigns: #{inspect assigns}"
    channel_id = msg[:channel_id] || assigns[:channel_id] #  || msg[:channel_id]
    if channel_id do
      UserSocket.push_message_box(socket, channel_id, assigns.user_id)
    end

    {:noreply, socket}
  end

  def handle_out(ev = "user:action", msg, socket) do
    debug ev, msg
    {:noreply, socket}
  end
  def handle_out("room:update:list", _msg, socket) do
    {:noreply, socket}
  end
  def handle_out("room:delete", _msg, socket) do
    {:noreply, socket}
  end
  def handle_out(ev = "lobby:" <> event, msg, socket) do
    debug ev, msg
    user_id = socket.assigns[:user_id]
    channel_id = msg[:channel_id]

    if Subscription.get_by user_id: user_id, channel_id: channel_id do
      Endpoint.broadcast CC.chan_room <> "lobby", event, msg
    end

    # push socket, event, msg
    {:noreply, socket}
  end

  ##########
  # Incoming message handlers

  def handle_in(pattern, %{"params" => params, "ucxchat" =>  ucxchat} = msg,
    socket) do
    # debug pattern, msg
    trace pattern, msg
    user = Helpers.get_user! socket.assigns.user_id
    if authorized? socket, String.split(pattern, "/"), params, ucxchat, user do
      UccChat.Web.ChannelRouter.route(socket, pattern, params, ucxchat)
    else
      push socket, "toastr:error", %{message: ~g"You are not authorized!"}
      {:noreply, socket}
    end
  end

  def handle_in(ev = "messages:load", msg, socket) do
    debug ev, msg

    {:noreply, socket}
  end

  def handle_in(ev = "message_popup:" <> cmd, msg, socket) do
    debug ev, msg
    resp = UccChat.MessagePopupService.handle_in(cmd, msg)
    {:reply, resp, socket}
  end

  def handle_in(ev = "message_cog:" <> cmd, msg, socket) do
    debug ev, msg
    resp =
      case UccChat.MessageCogService.handle_in(cmd, msg, socket) do
        {:nil, msg} ->
          {:ok, msg}
        {event, msg} ->
          broadcast! socket, event, %{}
          {:ok, msg}
      end

    {:reply, resp, socket}
  end
  def handle_in(ev = "message:get-body:" <> id, msg, socket) do
    debug ev, msg

    message = Message.get id, preload: [:attachments]
    body =
      case message.attachments do
        [] -> message.body
        [att|_] -> att.description
      end
    {:reply, {:ok, %{body: body}}, socket}
  end
  # default case
  def handle_in(event, msg, socket) do
    Logger.warn "RoomChannel no handler for: event: #{event}, " <>
      "msg: #{inspect msg}"
    {:noreply, socket}
  end


  #########
  # Private

  @room_commands ~w(set-owner set-moderator mute-user remove-user)

  defp authorized?(_socket, ["room_settings" | _], _params, ucxchat,
    user) do
    Permissions.has_permission? user, "edit-room",
      ucxchat["assigns"]["channel_id"]
  end
  defp authorized?(_socket, _pattern = ["room", command, _username], _params,
    ucxchat, user) when command in @room_commands do
    Permissions.has_permission? user, command,
      ucxchat["assigns"]["channel_id"]
  end

  defp authorized?(_socket, _pattern, _params, _ucxchat, _), do: true
end
