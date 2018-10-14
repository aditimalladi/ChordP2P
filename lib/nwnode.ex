defmodule NwNode do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def create(server) do
    GenServer.cast(server, {:create})
  end

  def join(server, n_dash) do
    GenServer.cast(server, {:join})
  end

  def stabilize(server) do
    GenServer.cast(server, {:stabilize})
  end

  def notify(server, n_dash) do
    GenServer.cast(server, {:notify})
  end

  def fix_fingers(server) do
    GenServer.cast(server, {:fix_fingers})
  end

  def closest_preceding_node(server, id) do
    GenServer.call(server, {:closest_preceding_node, id})
  end

  def find_successor(server, id) do
    GenServer.call(server, {:find_successor, id})
  end

  def get_predecessor(server) do
    GenServer.call(server, {:get_predecessor})
  end


  # finger - Finger Table
  # succ - Succesor of current node
  # pred - Predecessor of current node
  def init(:ok) do
    {:ok, %{:key => [], :finger => %{}, :succ => nil, :pred => nil, :id => Utils.hash_modulus(self())}}
  end

  def handle_cast({:create}, state) do
    state = Map.replace(state, :succ = state[:id]) 
    {:noreply, state}
  end

  def handle_cast({:join, n_dash}, state) do
    state = Map.replace(state, :pred = nil)
    n_dash_pid = Chief.lookup(MyChief, n_dash)
    new_succ = find_successor(n_dash_pid, state[:id])
    state = Map.replace(state, :succ = new_succ)
    {:noreply, state}
  end

  def handle_cast({:notify, n_dash}, state) do
    if(state[:pred] == nil || n_dash in state[:pred]..state[:id]) do
      state = Map.replace(state, :pred, n_dash)
      {:noreply, state}
    end
    {:noreply, state}
  end

  def handle_cast({:stabilize}, state) do
    x = get_predecessor(Chief.lookup(MyChief, state[:succ]))
    if(x in state[:id]..state[:succ]) do
      state = Map.replace(state, :succ, x)
      pid_succ = Chief.lookup(MyChief, state[:succ])
      notify(pid_succ, state[:id])
      {:noreply, state}
    end
    pid_succ = Chief.lookup(MyChief, state[:succ])
    notify(pid_succ, state[:id])
    {:noreply, state}
  end

  # def handle_cast({:fix_fingers}, state) do
  #   state = Map.replace(state, :succ = state[:id]) 
  #   {:noreply, state}
  # end

  #TODO: Streamline m
  # m = 10 here
  def handle_call({:closest_preceding_node, id}, _from, state) do
    finger = state[:finger]
    size = Enum.count(Map.get_keys(finger))
    list_m = Enum.reverse(0..size)
    Enum.each(list_m, fn(i)->
      if(finger[i] in state[:id]..id) do
        {:reply, finger[i], state}
      end
    end)
    {:reply, state[:id], state}
  end

  def handle_call({:find_successor, id}, _from, state) do
    if(id in state[:id]+1..state[:succ]) do
      {:reply, state[:succ], state}
    else
      n_dash = closest_preceding_node(id)
      n_dash_succ = find_successor(self(), id)
      {:reply, n_dash_succ, state}
    end
    {:reply, state[:id], state}
  end


  def handle_call({:get_predecessor}, _from, state) do
    {:reply, state[:pred], state}
  end





end


