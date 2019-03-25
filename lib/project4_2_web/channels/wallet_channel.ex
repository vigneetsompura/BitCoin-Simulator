defmodule Project42Web.WalletChannel do
    use Phoenix.Channel

    def join("wallet:"<>id, _params, socket) do
        {:ok, %{}, socket}
    end

    def handle_in("new_balance", msg, socket) do
        push socket, "new_balance", msg
        {:reply, :ok,  socket}
    end

end