defmodule Dexaggregatex.API do
	alias Dexaggregatex.API

	@moduledoc """
	Defines controllers, routers, channels to be used in the API like:

	    use Dexaggregatex.API, :controller
			use Dexaggregatex.API, :router
	    use Dexaggregatex.API, :view
	"""

	@doc """
	Standard implementation of an API controller.
	"""
	def controller do
		quote do
			use Phoenix.Controller, namespace: API
			import Plug.Conn
			import API.Format
			alias API.Router.Helpers, as: Routes
		end
	end

	@doc """
	Standard implementation of an API router.
	"""
	def router do
		quote do
			use Phoenix.Router
			import Plug.Conn
			import Phoenix.Controller
		end
	end

	@doc """
	Standard implementation of an API channel.
	"""
	def channel do
		quote do
			use Phoenix.Channel
		end
	end

	@doc false
	defmacro __using__(which) when is_atom(which) do
		apply(__MODULE__, which, [])
	end
end