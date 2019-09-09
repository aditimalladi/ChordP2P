defmodule Peer do
  use GenServer

  def start_link(m, data, node_name, opts) do
    GenServer.start_link(__MODULE__, [m, data, node_name], opts)
  end

  # creating a new chord network
  def create(server) do
    GenServer.cast(server, {:create})
  end

  # old_peer is a peer/node that already exists on the chord network
  def join(server, old_peer) do
    GenServer.cast(server, {:join, old_peer})
  end

  def stabilize(server) do
    GenServer.cast(server, {:stabilize})
  end

  def notify(server, peer_id) do
    GenServer.cast(server, {:notify, peer_id})
  end

  def fix_fingers(server) do
    GenServer.cast(server, {:fix_fingers})
  end

  # returns the successor of peer_id
  def find_succ(server, peer_id) do
    GenServer.call(server, {:find_succ, peer_id})
  end

  # returns current node's predecessor
  def get_predecessor(server) do
    GenServer.call(server, {:get_predecessor})
  end

  # returns current node's successor
  def get_successor(server) do
    GenServer.call(server, {:get_successor})
  end

  # sets the current GenServer's successor as succ
  def set_successor(server, succ) do
    GenServer.cast(server, {:set_successor, succ})
  end

  # sets the current GenServer's predecessor as succ
  def set_predecessor(server, pred) do
    GenServer.cast(server, {:set_predecessor, pred})
  end

  # returns the closest preceding node
  def closest_preceding_node(server, peer_id) do
    GenServer.call(server, {:closest_preceding_node, peer_id})
  end

  # returns the state of the current GenServer
  def get_state(server) do
    GenServer.call(server, {:get_state})
  end

  def init(args) do
    [m, data, node_name] = args
    id = Utils.hash_modulus(node_name)
    Chief.update_kash(MyChief, id, self())
    Chief.put(MyChief, id)
    # state of each node
    {:ok,
     %{
       :succ => nil,
       :pred => nil,
       :id => id,
       :finger_table => %{},
       :m => m,
       :work => false,
       :next => 0,
       :data => data,
       :counter => 0
     }}
  end

  # called for first node
  # sets the successor and predecessor as itself
  def handle_cast({:create}, state) do
    state = Map.replace(state, :succ, state[:id])
    state = Map.replace(state, :work, true)
    allow_work()
    init_fingers()
    :ets.insert(state[:data], {state[:id], state})
    {:noreply, state}
  end

  # new node asks old_peer to find it's(new node's) successor
  def handle_cast({:join, old_peer}, state) do
    old_peer_pid = Chief.lookup(MyChief, old_peer)
    pred = old_peer
    state = Map.replace(state, :pred, pred)
    state = Map.replace(state, :work, true)
    set_successor(old_peer_pid, state[:id])
    :ets.insert(state[:data], {state[:id], state})
    allow_work()
    init_fingers()
    {:noreply, state}
  end

  # runs periodically
  # checks the peer's immediate 2^0, succ
  # tells the succ about the peer/ i.e itself
  def handle_cast({:stabilize}, state) do
    succ_exists = Chief.lookup(MyChief, state[:succ])
    if(succ_exists == nil) do
      new_succ = Chief.get_succ(MyChief, state[:id])
      state = Map.replace(state, :succ, new_succ)
      new_succ_pid = Chief.lookup(MyChief, new_succ)
      Peer.set_predecessor(new_succ_pid, state[:id])
      :ets.insert(state[:data], {state[:id], state})
      if(state[:succ]!= state[:pred]) do
        succ = state[:succ]
        [{_, succ_state}] = :ets.lookup(state[:data], succ)
        x = succ_state[:pred]
        b_og = state[:succ]
        if(b_og != state[:id]) do
          [{_, b_state}] = :ets.lookup(state[:data], succ)
          b = b_state[:pred]
          if Utils.check_range_excl(x, state[:id], b) do
            state = Map.replace(state, :succ, x)
            x_pid = Chief.lookup(MyChief, x)
            Peer.notify(x_pid, state[:id])
            :ets.insert(state[:data], {state[:id], state})
            {:noreply, state}
          end
          succ_pid = Chief.lookup(MyChief, succ)
          Peer.notify(succ_pid, state[:id])
          :ets.insert(state[:data], {state[:id], state})
          {:noreply, state}
        end
      end
      :ets.insert(state[:data], {state[:id], state})
      {:noreply, state}
    else
      if(state[:succ]!= state[:pred]) do
        succ = state[:succ]
        [{_, succ_state}] = :ets.lookup(state[:data], succ)
        x = succ_state[:pred]
        b_og = state[:succ]
        if(b_og != state[:id]) do
          [{_, b_state}] = :ets.lookup(state[:data], succ)
          b = b_state[:pred]
          if Utils.check_range_excl(x, state[:id], b) do
            state = Map.replace(state, :succ, x)
            x_pid = Chief.lookup(MyChief, x)
            Peer.notify(x_pid, state[:id])
            :ets.insert(state[:data], {state[:id], state})
            {:noreply, state}
          end
          succ_pid = Chief.lookup(MyChief, succ)
          Peer.notify(succ_pid, state[:id])
          :ets.insert(state[:data], {state[:id], state})
          {:noreply, state}
        end
      end
      :ets.insert(state[:data], {state[:id], state})
      {:noreply, state}
    end
  end

  # notify is called periodically
  def handle_cast({:notify, peer_id}, state) do
    pred = state[:pred]
    if(pred == state[:id]) do
      if(pred == nil || Utils.check_range_excl(peer_id, pred, state[:id])) do
        state = Map.replace(state, :pred, peer_id)
        :ets.insert(state[:data], {state[:id], state})
        {:noreply, state}
      end
    else
      if(pred == nil || Utils.check_range_excl(peer_id, pred, state[:id])) do
        state = Map.replace(state, :pred, peer_id)
        :ets.insert(state[:data], {state[:id], state})
        {:noreply, state}
      end
    end

    {:noreply, state}
  end

  def handle_cast({:fix_fingers}, state) do
    next = state[:next]
    finger = state[:finger_table]
    next = next + 1
    if(next > 20) do
      next = 1
      temp = find_successorp(rem((state[:id] + :math.pow(2, next - 1)) |> trunc, :math.pow(2, 20) |> trunc),
          state)
      finger = Map.put(finger, next, temp)
      state = Map.replace(state, :finger_table, finger)
      state = Map.replace(state, :next, next)
      :ets.insert(state[:data], {state[:id], state})
      {:noreply, state}
    else
      temp = find_successorp(rem((state[:id] + :math.pow(2, next - 1)) |> trunc, :math.pow(2, 20) |> trunc),
          state)
      finger = Map.put(finger, next, temp)
      state = Map.replace(state, :finger_table, finger)
      state = Map.replace(state, :next, next)
      :ets.insert(state[:data], {state[:id], state})
      {:noreply, state}
    end
  end

  def handle_cast({:set_successor, succ}, state) do
    state = Map.replace(state, :succ, succ)
    :ets.insert(state[:data], {state[:id], state})
    {:noreply, state}
  end

  def handle_cast({:set_predecessor, pred}, state) do
    state = Map.replace(state, :pred, pred)
    :ets.insert(state[:data], {state[:id], state})
    {:noreply, state}
  end

  def handle_call({:find_succ, peer_id}, _from, state) do
    task = Task.async(Utils, :find_succ, [state[:id], peer_id, state[:data]])
    res = Task.await(task, :infinity)
    {:reply, res, state}
  end

  def handle_call({:get_predecessor}, _from, state) do
    {:reply, state[:pred], state}
  end

  def handle_call({:get_successor}, _from, state) do
    {:reply, state[:succ], state}
  end

  def handle_call({:closest_preceding_node, peer_id}, _from, state) do
    finger = state[:finger_table]
    size = Enum.count(Map.keys(finger))
    list_m = Enum.reverse(1..size)
    finger_list =
      Enum.map(list_m, fn i ->
        if(Utils.key_in_range_excl(finger[i], state[:id], peer_id)) do
          finger[i]
        end
      end)

    finger_list = Enum.uniq(finger_list)
    if(finger_list == [nil]) do
      state[:id]
    else
      finger_list = finger_list -- [nil]
      Enum.fetch!(finger_list, 0)
    end
  end

  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  defp find_successorp(peer_id, state) do
    # spawning a task to find the successor of the current GenServer, i.e, self()
    task = Task.async(Utils, :find_succ, [state[:id], peer_id, state[:data]])
    res = Task.await(task, :infinity)
    res
  end

  def closest_preceding_nodep(peer_id, state) do
    finger = state[:finger_table]
    size = Enum.count(Map.keys(finger))
    list_m = Enum.reverse(1..size)
    finger_list =
      Enum.map(list_m, fn i ->
        if(Utils.key_in_range_excl(finger[i], state[:id], peer_id)) do
          finger[i]
        end
      end)
    # ensuring no repeated elements in the list
    finger_list = Enum.uniq(finger_list)
    if(finger_list == [nil]) do
      state[:id]
    else
      finger_list = finger_list -- [nil]
      Enum.fetch!(finger_list, 0)
    end
  end

  # periodically calling stabilize and fix_fingers
  def handle_info(:work, state) do
    if(state[:work] == true) do
      fix_fingers(self())
      stabilize(self())
    end
    allow_work()
    {:noreply, state}
  end

  # periodically calling fix_fingers to populate the finger table initially
  def handle_info(:work_x, state) do
    if(state[:work] == true) do
      fix_fingers(self())
    end

    allow_work()
    {:noreply, state}
  end

  defp allow_work() do
    Process.send_after(self(), :work, 100)
  end

  defp init_fingers() do
    Enum.each(0..20, fn i ->
      Process.send_after(self(), :work_x, 100)
    end)
  end
end
