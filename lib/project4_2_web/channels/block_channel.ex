defmodule Project42Web.BlockChannel do
    use Phoenix.Channel

    def join("block:"<>id, _params, socket) do
        {:ok, %{}, socket}
    end

    def handle_in("new_block", msg, socket) do
        push socket, "new_block", msg
        {:reply, :ok,  socket}
    end

end
