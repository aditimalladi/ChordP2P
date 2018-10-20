defmodule Peer do
  use GenServer

  def start_link(m, opts) do
    GenServer.start_link(__MODULE__, m, opts)
  end

  def create(server) do
    IO.puts "Create genServer"
    GenServer.cast(server, {:create})
  end

  # new node will call join on existing peer/node on the network
  # old_peer is a peer/node that already exists on the chord network
  def join(server, old_peer) do
    # IO.puts "Join with #{old_peer}"
    GenServer.cast(server, {:join, old_peer})
  end

  def stabilize(server) do
    # IO.puts "Stabilize"
    GenServer.cast(server, {:stabilize})
  end

  def notify(server, peer_id) do
    # IO.puts "Notify"
    GenServer.cast(server, {:notify, peer_id})
  end

  def update_fingers(server) do
    # IO.puts "FixFingers"
    GenServer.cast(server, {:update_fingers})
  end

  def find_succ(server, peer_id) do
    # IO.puts "FindSucc of #{peer_id}"
    GenServer.call(server, {:find_succ, peer_id})
  end

  def get_predecessor(server) do
    GenServer.call(server, {:get_predecessor})
  end

  def get_successor(server) do
    GenServer.call(server, {:get_successor})
  end

  def set_successor(server, succ) do
    GenServer.cast(server, {:set_successor, succ})
  end

  def set_predecessor(server, pred) do
    GenServer.cast(server, {:set_predecessor, pred})
  end

  def closet_preceding_node(server, peer_id) do
    GenServer.call(server, {:closet_preceding_node, peer_id})
  end

  def get_state(server) do
    GenServer.call(server, {:get_state})
  end
  


  # state stores successor, predecessor, id = it's PID hash (it's identifier), finger table
  def init(m) do
    {:ok, %{:succ => nil, :pred => nil, :id => Utils.hash_modulus(self()), :finger_table => %{}, :m => m, :work => false, :next => 0}}
  end


  # called for first node
  # sets the successor and predecessor as itself
  def handle_cast({:create}, state) do
    # IO.puts "Create first node HC"
    state = Map.replace(state, :succ, state[:id]) 
    # state = Map.replace(state, :pred, state[:id]) 
    state = Map.replace(state, :work, true)
    allow_work()
    {:noreply, state}
  end

  # new node asks old_peer to find it's(new node's) successor
  def handle_cast({:join, old_peer}, state) do
    # IO.puts "Join #{state[:id]} with #{old_peer} HC"
    # state = Map.replace(state, :pred, nil)
    old_peer_pid = Chief.lookup(MyChief, old_peer)
    # state[:id] of the new node is sent
    # IO.puts "I'm here now"
    # IO.inspect old_peer_pid
    # IO.inspect old_peer
    # succ = Peer.find_succ(old_peer_pid, state[:id])
    pred = old_peer
    state = Map.replace(state, :pred, pred)
    state = Map.replace(state, :work, true)
    set_successor(old_peer_pid, state[:id])
    allow_work()
    {:noreply, state}
  end

  # runs periodically
  # checks the peer's immediate 2^0, succ
  # tells the succ about the peer/ i.e itself
  def handle_cast({:stabilize}, state) do
    # IO.puts "Stabilize on #{state[:id]}"
     if(state[:succ]!= state[:pred]) do
       succ = state[:succ]
       succ_pid = Chief.lookup(MyChief, succ)
       x = Peer.get_predecessor(succ_pid)
       b_og = state[:succ]
       if(b_og != state[:id]) do
        b_og_pid = Chief.lookup(MyChief, b_og)
        b = Peer.get_predecessor(b_og_pid)
        # IO.puts "Check range #{x} #{state[:id]} #{b}"
        if Utils.real_deal_exclusion(x, state[:id], b) do
          state = Map.replace(state, :succ, x)
          x_pid = Chief.lookup(MyChief, x)
          Peer.notify(x_pid, state[:id])
          {:noreply, state}
        end
        Peer.notify(succ_pid, state[:id])
        {:noreply, state}
       end
     end
    {:noreply, state}
  end

  # niotify is called periodically
  def handle_cast({:notify, peer_id}, state) do
    pred = state[:pred]
    # IO.puts "Check range NOTIFY #{peer_id} #{pred} #{state[:id]}"
    if(pred == state[:id]) do
      if(pred == nil || Utils.real_deal_exclusion(peer_id, pred, state[:id])) do
        state = Map.replace(state, :pred, peer_id)
        {:noreply, state}
      end
    else
      # IO.puts "Check range not self NOTIFY #{peer_id} #{pred} #{state[:id]}"
      if(pred == nil || Utils.real_deal_exclusion(peer_id, pred, state[:id])) do
        state = Map.replace(state, :pred, peer_id)
        {:noreply, state}
      end
    end
    {:noreply, state}
  end

  # m here is defined here as 10!!!!! NOT DYNAMIC
  def handle_cast({:update_fingers}, state) do
    # IO.puts "IN UPDATE_FINGERS #{state[:id]}"
    # IO.inspect state
    next = state[:next]
    finger = state[:finger_table]
    next = next + 1
    if(next > 10) do
      # IO.puts "It this being reached?"
      next = 1
      temp = find_successorp(rem(state[:id] + :math.pow(2, next - 1) |> trunc, 1024), state)
      finger = Map.put(finger, next, temp)
      state = Map.replace(state, :finger_table, finger)
      state = Map.replace(state, :next, next)
      {:noreply, state}
    end
    temp = find_successorp(rem(state[:id] + :math.pow(2, next - 1) |> trunc, 1024), state)
    # IO.puts "State id #{state[:id]} and the temp #{temp}"
    finger = Map.put(finger, next, temp)
    state = Map.replace(state, :finger_table, finger)
    state = Map.replace(state, :next, next)
    {:noreply, state}
  end

  def handle_cast({:set_successor, succ}, state) do
    state = Map.replace(state, :succ, succ)
    # finger = state[:finger_table]
    # finger = Map.put(finger, 0, succ)
    # state = Map.replace(state, :finger_table, finger)
    {:noreply, state}
  end

  def handle_cast({:set_predecessor, pred}, state) do
    state = Map.replace(state, :pred, pred)
    {:noreply, state}
  end

  

  def handle_call({:find_succ, peer_id}, _from, state) do
    # IO.puts "FindSucc on #{state[:id]} with #{peer_id} HC"
    if (state[:id] == state[:succ]) do
      {:reply, state[:succ], state}
    else
      if(Utils.real_succ_incl(peer_id, state[:id], state[:succ])) do
        # IO.puts "GenServer INCLUSION of UTILS"
        {:reply, state[:succ], state}
      else
        peer_pid = Chief.lookup(MyChief, peer_id)
        n_dash = closet_preceding_nodep(peer_id, state)
        if(n_dash == state[:id]) do
          k = find_successorp(peer_id, state)
          {:reply, k, state}
        else
          n_dash_pid = Chief.lookup(MyChief, n_dash)
          k = find_succ(n_dash_pid, peer_id)
          {:reply, k, state}
        end
      end
    end
  end

  def handle_call({:get_predecessor}, _from, state) do
    # IO.puts "get_predecessor"
    {:reply, state[:pred], state}
  end

  def handle_call({:get_successor}, _from, state) do
    # IO.puts "get_successor"
    {:reply, state[:succ], state}
  end

  def handle_call({:closet_preceding_node, peer_id}, _from, state) do
    finger = state[:finger_table]
    size = Enum.count(Map.keys(finger))
    list_m = Enum.reverse(1..size)
    finger_list = Enum.map(list_m, fn(i)->
      if(Utils.real_succ_excl(finger[i], state[:id], peer_id)) do
        finger[i]
      end
    end)
    finger_list = Enum.uniq(finger_list)
    # here is what can be returned from the function
    if(finger_list == [nil]) do
      state[:id]
    else
      finger_list = finger_list -- [nil]
      Enum.fetch!(finger_list, 0)
    end
  end

  def handle_call({:get_state}, _from, state) do
    # IO.puts "Get state"
    {:reply, state, state}
  end

  defp find_successorp(peer_id, state) do
    # IO.puts "find_successorp"
    # IO.inspect state
    if(Utils.real_succ_incl(peer_id, state[:id], state[:succ])) do
      # IO.puts "FIND SUCC INSIDE UTILS"
      state[:succ]
    else
      n_dash = closet_preceding_nodep(peer_id, state)
      n_dash_pid = Chief.lookup(MyChief, n_dash)
      if(n_dash == state[:id]) do
        find_successorp(peer_id, state)
      else
        find_succ(n_dash_pid, peer_id)
      end
    end
  end

  def closet_preceding_nodep(peer_id, state) do
    finger = state[:finger_table]
    size = Enum.count(Map.keys(finger))
    list_m = Enum.reverse(1..size)
    finger_list = Enum.map(list_m, fn(i)->
      if(Utils.real_succ_excl(finger[i], state[:id], peer_id)) do
        finger[i]
      end
    end)
    finger_list = Enum.uniq(finger_list)
    # here is what can be returned from the function
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
      # IO.puts "Stabilize and fix fingers"
      # stabilize(self())
      update_fingers(self())
    end
    allow_work()
    {:noreply, state}
  end

  defp allow_work() do
    Process.send_after(self(), :work, 100) # after 100 ms
  end


end