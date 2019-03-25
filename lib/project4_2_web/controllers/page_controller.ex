defmodule Project42Web.PageController do
  use Project42Web, :controller

  def index(conn, _params) do
    render(conn, "index.html", params: %{:type=>"config"})
  end
end
