defmodule Project42Web.StatusChannel do
    use Phoenix.Channel

    def join("status:"<>id, _params, socket) do
        {:ok, %{}, socket}
    end

    def handle_in("new_status", msg, socket) do
        push socket, "new_status", msg
        {:reply, :ok,  socket}
    end

end
