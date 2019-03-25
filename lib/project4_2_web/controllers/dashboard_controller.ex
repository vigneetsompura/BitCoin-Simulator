defmodule Project42Web.DashboardController do
    use Project42Web, :controller
  
    def startserver(conn, %{"miners"=> miners, "wallets"=> wallets, "rewards" => rewards,
     "max_miners" => max_miners, "add_min_miners" => add_min_miners, "add_max_miners" => add_max_miners, "add_miner_delay" => add_miner_delay,
     "add_min_transactions" => add_min_transactions, "add_max_transactions" => add_max_transactions, "add_transaction_delay" => add_transaction_delay, 
     "reward_change_rate" => reward_change_rate}) do


      Galleon.start(String.to_integer(miners),String.to_integer(wallets),String.to_integer(rewards),String.to_integer(max_miners),
      String.to_integer(add_min_miners),String.to_integer(add_max_miners),String.to_integer(add_miner_delay),
      String.to_integer(add_min_transactions),String.to_integer(add_max_transactions),String.to_integer(add_transaction_delay),
      String.to_integer(reward_change_rate))

      render(conn, "redirect.html", params: %{:type=>"redirect"})
    end

    def index(conn, _params) do

      block_map = Galleon.block_map()
      render(conn, "dashboard.html", params: %{:type=>"dashboard", :block_map => block_map})
    end

  end