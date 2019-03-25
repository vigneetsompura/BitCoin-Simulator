defmodule Project42Web.WalletController do
  use Project42Web, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def balance(conn, %{"id" => id}) do
    balance = Galleon.balance(String.to_integer(id))
    render(conn, "balance.html", params: %{:type =>"wallet", :id => id, :balance => balance})
  end
end
