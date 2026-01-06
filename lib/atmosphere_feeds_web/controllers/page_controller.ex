defmodule AtmosphereFeedsWeb.PageController do
  use AtmosphereFeedsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
