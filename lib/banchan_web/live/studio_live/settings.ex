defmodule BanchanWeb.StudioLive.Settings do
  @moduledoc """
  Banchan studio profile viewing and editing.
  """
  use BanchanWeb, :surface_view

  alias Surface.Components.{Form, Link}

  alias Banchan.Studios
  alias Banchan.Studios.{Notifications, Studio}

  import BanchanWeb.StudioLive.Helpers

  alias BanchanWeb.Components.Button

  alias BanchanWeb.Components.Form.{
    Checkbox,
    HiddenInput,
    MarkdownInput,
    MultipleSelect,
    Select,
    Submit,
    TagsInput,
    TextInput,
    UploadInput
  }

  alias BanchanWeb.StudioLive.Components.{Blocklist, StudioLayout}

  @impl true
  def mount(params, _session, socket) do
    socket = assign_studio_defaults(params, socket, true, false)

    currencies =
      Studios.Common.supported_currencies()
      |> Enum.map(fn currency ->
        %{name: name, symbol: symbol} = Money.Currency.get(currency)
        {:"#{name} (#{symbol})", currency}
      end)

    {:ok,
     assign(socket,
       tags: socket.assigns.studio.tags,
       changeset: Studio.profile_changeset(socket.assigns.studio, %{}),
       currencies: [{:"Currencies...", nil} | currencies],
       remove_card: false,
       remove_header: false,
       subscribed?:
         Notifications.user_subscribed?(socket.assigns.current_user, socket.assigns.studio)
     )
     |> allow_upload(:card_image,
       # TODO: Be less restrictive here
       accept: ~w(.jpg .jpeg .png),
       max_entries: 1,
       max_file_size: 10_000_000
     )
     |> allow_upload(:header_image,
       # TODO: Be less restrictive here
       accept: ~w(.jpg .jpeg .png),
       max_entries: 1,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, socket |> assign(uri: uri)}
  end

  @impl true
  def handle_event("toggle_subscribed", _, socket) do
    if socket.assigns.subscribed? do
      Notifications.unsubscribe_user!(socket.assigns.current_user, socket.assigns.studio)
    else
      Notifications.subscribe_user!(socket.assigns.current_user, socket.assigns.studio)
    end

    {:noreply, assign(socket, subscribed?: !socket.assigns.subscribed?)}
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def handle_event("submit", val, socket) do
    card_image =
      consume_uploaded_entries(socket, :card_image, fn %{path: path}, entry ->
        {:ok,
         Studios.make_card_image!(
           socket.assigns.current_user,
           path,
           socket.assigns.current_user_member? || :admin in socket.assigns.current_user.roles ||
             :mod in socket.assigns.current_user.roles,
           entry.client_type,
           entry.client_name
         )}
      end)
      |> Enum.at(0)

    header_image =
      consume_uploaded_entries(socket, :header_image, fn %{path: path}, entry ->
        {:ok,
         Studios.make_header_image!(
           socket.assigns.current_user,
           path,
           socket.assigns.current_user_member? || :admin in socket.assigns.current_user.roles ||
             :mod in socket.assigns.current_user.roles,
           entry.client_type,
           entry.client_name
         )}
      end)
      |> Enum.at(0)

    case Studios.update_studio_profile(
           socket.assigns.current_user,
           socket.assigns.studio,
           socket.assigns.current_user_member?,
           Enum.into(val["studio"], %{
             "card_img_id" => (card_image && card_image.id) || val["studio"]["card_image_id"],
             "header_img_id" =>
               (header_image && header_image.id) || val["studio"]["header_image_id"]
           })
         ) do
      {:ok, studio} ->
        socket =
          socket
          |> assign(changeset: Studio.profile_changeset(studio, %{}), studio: studio)
          |> put_flash(:info, "Profile updated")
          |> push_redirect(to: Routes.studio_settings_path(Endpoint, :show, studio.handle))

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(changeset: changeset)}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not authorized to edit this studio")
         |> push_redirect(
           to: Routes.studio_shop_path(Endpoint, :show, socket.assigns.studio.handle)
         )}
    end
  end

  def handle_event("change", val, socket) do
    changeset =
      socket.assigns.studio
      |> Studio.profile_changeset(val["studio"])
      |> Map.put(:action, :update)

    socket = assign(socket, changeset: changeset)
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_card_upload", %{"ref" => ref}, socket) do
    {:noreply, socket |> cancel_upload(:card_image, ref)}
  end

  @impl true
  def handle_event("cancel_header_upload", %{"ref" => ref}, socket) do
    {:noreply, socket |> cancel_upload(:header_image, ref)}
  end

  def handle_event("remove_card", _, socket) do
    {:noreply, assign(socket, remove_card: true)}
  end

  def handle_event("remove_header", _, socket) do
    {:noreply, assign(socket, remove_header: true)}
  end

  def handle_info(%{event: "follower_count_changed", payload: new_count}, socket) do
    {:noreply, socket |> assign(followers: new_count)}
  end

  @impl true
  def render(assigns) do
    ~F"""
    <StudioLayout
      id="studio-layout"
      current_user={@current_user}
      flashes={@flash}
      studio={@studio}
      followers={@followers}
      current_user_member?={@current_user_member?}
      tab={:settings}
      padding={0}
      uri={@uri}
    >
      <div class="w-full md:bg-base-300">
        <div class="max-w-xl w-full rounded-xl p-10 mx-auto md:my-10 bg-base-100">
          <h2 class="text-xl py-6">Notifications</h2>
          <div class="pb-6">Manage default notification settings for this studio. For example, whether to receive notifications for new commission requests.</div>
          <Button click="toggle_subscribed">
            {#if @subscribed?}
              Unsubscribe
            {#else}
              Subscribe
            {/if}
          </Button>

          <div class="divider" />

          <h2 class="text-xl py-6">Stripe Dashboard</h2>
          <div class="pb-6">
            You can manage your Stripe account details, such as your bank account, and see stats on previous payouts, over on your Stripe Express Dashboard.
          </div>
          <Link
            label="Go to Dashboard"
            class="btn btn-primary"
            to={Routes.stripe_dashboard_path(Endpoint, :dashboard, @studio.handle)}
          />

          <div class="divider" />

          <h2 class="text-xl py-6">Edit Studio Profile</h2>
          <Form class="flex flex-col gap-2" for={@changeset} change="change" submit="submit">
            <TagsInput
              id="studio_tags"
              info="Type to search for existing tags. Press Enter or Tab to add the tag. You can make it whatever you want as long as it's 100 characters or shorter."
              name={:tags}
            />
            <TextInput name={:name} info="Display name for studio" icon="user" opts={required: true} />
            <TextInput name={:handle} icon="at" opts={required: true} />
            <Checkbox
              name={:mature}
              label="Mature"
              info="Mark this studio as exclusively for mature content. You can still make indiviual mature offerings if this is unchecked."
            />
            <Select
              name={:default_currency}
              info="Default currency to display in currencies dropdown when entering invoice amounts."
              options={@currencies}
              opts={required: true}
            />
            <MultipleSelect
              name={:payment_currencies}
              info="Available currencies for invoicing purposes."
              options={@currencies}
              opts={required: true}
            />
            <div class="relative">
              {#if Enum.empty?(@uploads.card_image.entries) && (@remove_card || !(@studio && @studio.card_img_id))}
                <HiddenInput name={:card_image_id} value={nil} />
                <div class="aspect-video bg-base-300 w-full" />
              {#elseif !Enum.empty?(@uploads.card_image.entries)}
                <button
                  type="button"
                  phx-value-ref={(@uploads.card_image.entries |> Enum.at(0)).ref}
                  class="btn btn-xs btn-circle absolute right-2 top-2"
                  :on-click="cancel_card_upload"
                >✕</button>
                {Phoenix.LiveView.Helpers.live_img_preview(Enum.at(@uploads.card_image.entries, 0),
                  class: "object-cover aspect-video rounded-xl w-full"
                )}
              {#else}
                <button
                  type="button"
                  class="btn btn-xs btn-circle absolute right-2 top-2"
                  :on-click="remove_card"
                >✕</button>
                <HiddenInput name={:card_image_id} value={@studio.card_img_id} />
                <img
                  class="object-cover aspect-video rounded-xl w-full"
                  src={Routes.public_image_path(Endpoint, :image, @studio.card_img_id)}
                />
              {/if}
            </div>
            <UploadInput
              label="Card Image"
              hide_list
              upload={@uploads.card_image}
              cancel="cancel_card_upload"
            />
            <div class="relative">
              {#if Enum.empty?(@uploads.header_image.entries) &&
                  (@remove_header || !(@studio && @studio.header_img_id))}
                <HiddenInput name={:header_image_id} value={nil} />
                <div class="aspect-header-image bg-base-300 w-full" />
              {#elseif !Enum.empty?(@uploads.header_image.entries)}
                <button
                  type="button"
                  phx-value-ref={(@uploads.header_image.entries |> Enum.at(0)).ref}
                  class="btn btn-xs btn-circle absolute right-2 top-2"
                  :on-click="cancel_header_upload"
                >✕</button>
                {Phoenix.LiveView.Helpers.live_img_preview(Enum.at(@uploads.header_image.entries, 0),
                  class: "object-cover aspect-header-image rounded-xl w-full"
                )}
              {#else}
                <button
                  type="button"
                  class="btn btn-xs btn-circle absolute right-2 top-2"
                  :on-click="remove_header"
                >✕</button>
                <HiddenInput name={:header_image_id} value={@studio.header_img_id} />
                <img
                  class="object-cover aspect-header-image rounded-xl w-full"
                  src={Routes.public_image_path(Endpoint, :image, @studio.header_img_id)}
                />
              {/if}
            </div>
            <UploadInput
              label="Header Image"
              hide_list
              upload={@uploads.header_image}
              cancel="cancel_header_upload"
            />
            <MarkdownInput
              id="about"
              info="Displayed in the 'About' page. The first few dozen characters will also be displayed as the description in studio cards."
              name={:about}
            />
            <MarkdownInput
              id="default-terms"
              info="Default Terms of Service to display to users, when an offering hasn't configured its own."
              name={:default_terms}
            />
            <MarkdownInput
              id="default-template"
              info="Default commission submission template, when an offering hasn't configured its own."
              name={:default_template}
            />
            <Submit label="Save" />
          </Form>

          <div class="divider" />

          <div class="h-40 overflow-auto">
            <Blocklist id="studio-blocklist" studio={@studio} />
          </div>
        </div>
      </div>
    </StudioLayout>
    """
  end
end
