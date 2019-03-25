defmodule Project42Web.TransactionController do
    use Project42Web, :controller

    def index(conn,  _params) do
      render(conn, "transaction.html", params: %{:type=>"transactioninput"})
    end

    def newtransaction(conn, %{"sender"=>sender, "receiver"=> receiver, "amount"=>amount}) do
        transaction_id = Galleon.transact(String.to_integer(sender),String.to_integer(receiver),String.to_float(amount))
        render(conn, "transactionredirect.html", params: %{:type=>"transaction", :transaction_id => transaction_id})
    end

  end