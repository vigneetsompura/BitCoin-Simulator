defmodule Project42Web.BlockController do
    use Project42Web, :controller

    def index(conn,  %{"id" => id}) do
      block = Galleon.get_block(id)
      render(conn, "block.html", params: %{:type=>"block", :block => block})
    end

  end