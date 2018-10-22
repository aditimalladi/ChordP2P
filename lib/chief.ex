defmodule Chief do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  # putting a new node into node_list and makes sure sorted in ascending order
  def put(server, new_node) do
    GenServer.cast(server, {:put, new_node})
  end

  # updates lookuptable with the hash, pid pairs
  def update_kash(server, new_kash, new_node) do
    GenServer.cast(server, {:update_kash, new_kash, new_node})
  end

  # kash : key-hash, lookuptable is "looked up" returns pid of key-hash
  def lookup(server, kash) do
    GenServer.call(server, {:lookup, kash})
  end

  # gets the node_list
  def get(server) do
    GenServer.call(server, {:get})
  end

  # gets the node_list
  def get_succ(server, node) do
    GenServer.call(server, {:get_succ, node})
  end

  def delete(server, node) do
    GenServer.cast(server, {:delete, node})
  end

  def init(:ok) do
    {:ok, %{:node_list => [], :lookuptable => %{}}}
  end

  def handle_cast({:put, new_node}, state) do
    node_list = state[:node_list]
    node_list = node_list ++ [new_node]
    node_list = Enum.sort(node_list)
    state = Map.replace(state, :node_list, node_list)
    {:noreply, state}
  end

  def handle_cast({:delete, node}, state) do
    node_list = state[:node_list]
    lookup_table = state[:lookuptable]
    node_list = node_list -- [node]
    lookup_table = Map.delete(lookup_table, node)
    state = Map.replace(state, :lookuptable, lookup_table)
    state = Map.replace(state, :node_list, node_list)
    {:noreply, state}
  end

  def handle_cast({:update_kash, new_kash, new_node}, state) do
    lookup_table = state[:lookuptable]
    lookup_table = Map.put(lookup_table, new_kash, new_node)
    state = Map.replace(state, :lookuptable, lookup_table)
    {:noreply, state}
  end

  

  def handle_call({:get}, _from, state) do
    {:reply, state[:node_list], state}
  end

  def handle_call({:lookup, kash}, _from, state) do
    {:reply, state[:lookuptable][kash], state}
  end

  def handle_call({:get_succ, node}, _from, state) do
    node_list = state[:node_list]
    node_i = Enum.find_index(node_list, fn i -> i==node end)
    {:reply, Enum.fetch!(node_list, node_i+1), state}
  end
end
