defmodule Changelog.AuthController do
  use Changelog.Web, :controller

  alias Changelog.Person

  def new(conn, %{"auth" =>  %{"email" => email}}) do
    person = Repo.one!(from p in Person, where: p.email == ^email)

    auth_token = Base.encode16(:crypto.rand_bytes(8))
    expires_at =
      Timex.DateTime.now
      |> Timex.add(Timex.Time.to_timestamp(15, :minutes))

    changeset = Person.auth_changeset(person, %{
      auth_token: auth_token,
      auth_token_expires_at: expires_at
    })

    case Repo.update(changeset) do
      {:ok, person} ->
        render conn, "new.html", person: person
      {:error, _} ->
        conn
        |> put_flash(:info, "try again!")
        |> render("new.html", person: nil)
    end
  end

  def new(conn, _params) do
    render conn, "new.html", person: nil
  end

  def create(conn, %{"token" => token}) do
    [email, auth_token] = Person.decoded_auth(token)
    person = Repo.get_by(Person, email: email, auth_token: auth_token)

    cond do
      person &&
      Timex.before?(Timex.DateTime.now, person.auth_token_expires_at) ->
        Repo.update(Person.sign_in_changes(person))
        conn
        |> assign(:current_user, person)
        |> put_encrypted_cookie("_changelog_user", person.id)
        |> configure_session(renew: true)
        |> redirect(to: page_path(conn, :index))
      true ->
        conn
        |> put_flash(:info, "Whoops!")
        |> render("new.html", person: nil)
    end
  end

  def delete(conn, _params) do
    conn
      |> configure_session(drop: true)
      |> delete_resp_cookie("_changelog_user")
      |> redirect(to: page_path(conn, :index))
  end
end