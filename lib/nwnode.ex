defmodule NwNode do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def create(server) do
    IO.puts "Create genServer"
    GenServer.cast(server, {:create})
  end

  def join(server, n_dash) do
    GenServer.cast(server, {:join, n_dash})
  end

  def stabilize(server) do
    GenServer.cast(server, {:stabilize})
  end

  def notify(server, n_dash) do
    GenServer.cast(server, {:notify, n_dash})
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
    # allow_work()
    {:ok, %{:key => [], :finger => %{}, :succ => nil, :pred => nil, :id => Utils.hash_modulus(self()), :next => 0, :work => false}}
  end

  def handle_cast({:create}, state) do
    IO.puts "Create"
    state = Map.replace(state, :succ, state[:id]) 
    state = Map.replace(state, :pred, state[:id]) 
    state = Map.replace(state, :work, true)
    allow_work() 
    {:noreply, state}
  end

  def handle_cast({:join, n_dash}, state) do
    IO.puts "Join"
    state = Map.replace(state, :pred, nil)
    n_dash_pid = Chief.lookup(MyChief, n_dash)
    new_succ = find_successor(n_dash_pid, state[:id])
    state = Map.replace(state, :succ, new_succ)
    state = Map.replace(state, :work, true) 
    allow_work()
    {:noreply, state}
  end

  def handle_cast({:notify, n_dash}, state) do
    IO.puts "Notify"
    if(state[:pred] == nil || n_dash in state[:pred]..state[:id]) do
      state = Map.replace(state, :pred, n_dash)
      {:noreply, state}
    end
    {:noreply, state}
  end

  def handle_cast({:stabilize}, state) do
    IO.puts "Stabilize"
    x = if(state[:succ] == state[:id], do: state[:pred], else: get_predecessor(Chief.lookup(MyChief, state[:succ])))
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

    #TODO: Streamline 10
    #TODO: Implement check_pred function (in paper) that checks for the failure of nodes
  def handle_cast({:fix_fingers}, state) do
    IO.puts "fix_fingers"

    next = state[:next]
    finger = state[:finger]
    next = next + 1
    if(next > 10) do
      next = 1
      temp = find_successorp(state, state[:id] + :math.pow(2, next - 1) |> trunc)
      finger = Map.put(finger, next, temp)
      state = Map.replace(state, :finger, finger)
      state = Map.replace(state, :next, next)
      {:noreply, state}
    end
    temp = find_successorp(state, state[:id] + :math.pow(2, next - 1) |> trunc)
    finger = Map.put(finger, next, temp)
    state = Map.replace(state, :finger, finger)
    state = Map.replace(state, :next, next)
    {:noreply, state}
  end

  def handle_call({:closest_preceding_node, id}, _from, state) do
    IO.puts "closest_preceding_node - GENSERVER"
    finger = state[:finger]
    size = Enum.count(Map.keys(finger))
    list_m = Enum.reverse(0..size)
    Enum.each(list_m, fn(i)->
      if(finger[i] in state[:id]..id) do
        {:reply, finger[i], state}
      end
    end)
    {:reply, state[:id], state}
  end

  def handle_call({:find_successor, id}, _from, state) do
    IO.puts "find_successor - GENSERVER"
    if(state[:id] == state[:succ] || id in state[:id]+1..state[:succ]) do
      {:reply, state[:succ], state}
    else
      IO.inspect n_dash = closest_preceding_nodep(state, id)
      n_dash_pid = Chief.lookup(MyChief, n_dash)
      n_dash_succ = find_successor(n_dash_pid, id)
      {:reply, n_dash_succ, state}
    end
  end


  def handle_call({:get_predecessor}, _from, state) do
    IO.puts "get_predecessor"
    {:reply, state[:pred], state}
  end

  # periodically calling stabilize and fix_fingers
  def handle_info(:work, state) do
    IO.puts "work"
    if(state[:work] == true) do
      stabilize(self())
      fix_fingers(self())
    end
    {:noreply, state}
  end

  defp allow_work() do
    IO.puts "allow_work"
    Process.send_after(self(), :work, 100) # after 100 ms
  end

  defp find_successorp(state, id) do
    IO.puts "find_successorPPPPP"
    if(state[:id] == state[:succ] || id in state[:id]+1..state[:succ]) do
      state[:succ]
    else
      n_dash = closest_preceding_nodep(state, id)
      if(n_dash == state[:id]) do
        n_dash_pid = Chief.lookup(MyChief, n_dash)
        n_dash_succ = find_successorp(state, id)
        n_dash_succ
      else
        n_dash_pid = Chief.lookup(MyChief, n_dash)
        n_dash_succ = find_successor(n_dash_pid, id)
        n_dash_succ
      end
    end
  end

  defp closest_preceding_nodep(state, id) do
    IO.puts "closest_preceding_nodePPPPPPPPP, #{id}"
    finger = state[:finger]
    size = Enum.count(Map.keys(finger))
    list_m = Enum.reverse(0..size)
    finger_list = Enum.map(list_m, fn(i)->
      if(finger[i] in state[:id]..id) do
        finger[i]
      end
    end)
    finger_list = Enum.uniq(finger_list)

    if(finger_list == [nil]) do
      state[:id]
    else
      Enum.fetch!(finger_list, 0)
    end
  end


end


