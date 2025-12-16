defmodule GameServerWeb.Pagination do
  @moduledoc """
  Small helper to build pagination meta for API list endpoints.

  Use as: GameServerWeb.Pagination.meta(page, page_size, count, total_count)
  """

  @spec meta(integer, integer, integer, integer) :: map
  def meta(page, page_size, count, total_count) when is_integer(page) and is_integer(page_size) do
    total_pages = if page_size > 0, do: div(total_count + page_size - 1, page_size), else: 0

    %{
      page: page,
      page_size: page_size,
      count: count,
      total_count: total_count,
      total_pages: total_pages,
      has_more: count == page_size
    }
  end
end
