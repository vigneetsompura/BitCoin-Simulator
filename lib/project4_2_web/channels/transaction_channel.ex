defmodule Project42Web.TransactionChannel do
    use Phoenix.Channel

    def join("transaction:"<>id, _params, socket) do
        {:ok, %{}, socket}
    end

    def handle_in("transaction_status", msg, socket) do
        push socket, "transaction_status", msg
        {:reply, :ok,  socket}
    end

end
