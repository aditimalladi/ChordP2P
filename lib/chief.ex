defmodule Chief do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def put(server, new_node) do
    GenServer.cast(server, {:put, new_node})
  end

  def update_kash(server, new_kash, new_node) do
    GenServer.cast(server, {:put, new_kash, new_node})
  end

  # kash : key-hash
  def lookup(server, kash) do
    GenServer.call(server, {:lookup, kash})
  end

  def get(server) do
    GenServer.call(server, {:get})
  end

  def init(:ok) do
    {:ok, %{:node_list => [], :lookuptable => %{}}}
  end

  def handle_cast({:set_neighbors, new_node}, state) do
    state = [state | new_node]
    state = Enum.sort(state)
    {:noreply, state}
  end

  def handle_cast({:update_kash, new_kash, new_node}, state) do
    lookup_table = state[:lookuptable]
    lookup_table = Map.put(lookup_table, new_kash, new_node)
    state = Map.replace(state, :lookuptable, lookup_table)
    {:noreply, state}
  end

  def handle_call({:get}, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:lookup, kash}, _from, state) do
    {:reply, state[:lookupTable][kash], state}
  end

end