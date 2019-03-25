defmodule Project42Web.Router do
  use Project42Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Project42Web do
    pipe_through :browser

    get "/", PageController, :index
    get "/dashboard/:miners/:wallets/:rewards/:max_miners/:add_min_miners/:add_max_miners/:add_miner_delay/:add_min_transactions/:add_max_transactions/:add_transaction_delay/:reward_change_rate", DashboardController, :startserver
    get "/balance/:id", WalletController, :balance
    get "/dashboard", DashboardController, :index
    get "/block/:id", BlockController, :index
    get "/transaction", TransactionController, :index
    get "/transaction/:sender/:receiver/:amount", TransactionController, :newtransaction
  end

  # Other scopes may use custom stacks.
  # scope "/api", Project42Web do
  #   pipe_through :api
  # end
end
