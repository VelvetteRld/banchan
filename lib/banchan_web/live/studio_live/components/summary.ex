defmodule BanchanWeb.StudioLive.Components.Commissions.Summary do
  @moduledoc """
  Summary card for the Commissions Page sidebar
  """
  use BanchanWeb, :live_component

  import Ecto.Changeset

  alias BanchanWeb.Components.Card

  prop changeset, :struct, required: true

  def render(assigns) do
    ~F"""
    <Card>
      <:header>
        Summary
      </:header>

      <ul class="divide-y">
        {#for item <- fetch_field!(@changeset, :line_items)}
          <li class="line-item container p-4">
            <div class="float-right">
              {Money.to_string(item.amount)}
              {#if !item.sticky}
                <i class="fas fa-times-circle" />
              {/if}
            </div>
            <div>{item.name}</div>
            <div>{item.description}</div>
          </li>
        {/for}
      </ul>
      <hr>
      <div class="container">
        <p class="p-4">Estimate: <span class="float-right">
                  {Money.to_string(
                      Enum.reduce(
                        fetch_field!(@changeset, :line_items),
                        # TODO: Using :USD here is a bad idea for later, but idk how to do it better yet.
                        Money.new(0, :USD),
                        fn item, acc -> Money.add(acc, item.amount || Money.new(0, :USD)) end
                      )
                    )}
          </span></p>
      </div>

      <:footer>
        <a class="text-center rounded-full py-1 px-5 btn btn-secondary m-1" href="#">Add Offering</a>
      </:footer>
    </Card>
    """
  end
end
