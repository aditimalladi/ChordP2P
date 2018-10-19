defmodule Utils do
  # node's pid is passed and then converted to a string
  # that string is then hashed using SHA-1 ans trucated to 2^10 bits
  def hash_modulus(node_pid) do
    str_num = :erlang.pid_to_list(node_pid)
    num = :crypto.hash(:sha, str_num) |> Base.encode16
    {int_num, _} = Integer.parse(num, 16)
    rem(int_num, :math.pow(2,10) |> trunc)
  end

  # for when a == self()
  def check_in_range_self(x, a, b, accumulator, state) do
    a_pid = Chief.lookup(MyChief, a)
    succ = state[:succ]
    succ_pid = Chief.lookup(MyChief, succ)
    if a == b do
      if x == a do
        true
      else
        accumulator
      end
    else
      if(x == succ) do
        # HERE
        state = Peer.get_state(succ_pid)
        check_in_range_self(x, succ, b, (succ == x) || accumulator, state)
      else
        check_in_range(x, succ, b, (succ == x) || accumulator)
      end
    end
  end

  # to check if the given node is in the given range
  def check_in_range(x, a, b, accumulator) do
    a_pid = Chief.lookup(MyChief, a)
    IO.puts "Check in range NOT SELF #{x} #{a} #{b} HC"
    IO.inspect self()
    succ = Peer.get_successor(a_pid)
    succ_pid = Chief.lookup(MyChief, succ)
    if a == b do
      if x == a do
        true
      else
        accumulator
      end
    else
      if(x == succ) do
        # HERE
        state = Peer.get_state(succ_pid)
        check_in_range_self(x, succ, b, (succ == x) || accumulator, state)
      else
        check_in_range(x, succ, b, (succ == x) || accumulator)
      end
    end
  end


  def real_deal_exclusion(x, a, b) do
    IO.puts "REAL DEAL MOFOOOOOO #{x} #{a} #{b} HC"
    IO.inspect x
    IO.inspect a
    IO.inspect b
    node_list = Chief.get(MyChief)
    IO.inspect node_list
    cond do
      a == nil || b == nil || x== nil ->
        false
      a not in node_list || b not in node_list ->
        false
      a == b ->
        false
      a < b ->
        index_a = Enum.find_index(node_list, fn(i) -> i==a end)
        index_b = Enum.find_index(node_list, fn(i) -> i==b end)
        IO.puts "#{a} this is a"
        IO.puts "#{b} this is b"
        IO.puts "#{index_a} this is a_index"
        IO.puts "#{index_b} this is b_index"
        IO.puts "#{index_b-index_a-1} this is idk what"
        check_list = Enum.slice(node_list, index_a+1, index_b-index_a-1)
        x in check_list
      a > b ->
          index_a = Enum.find_index(node_list, fn(i) -> i==a end)
          index_b = Enum.find_index(node_list, fn(i) -> i==b end)
          last_index = length(node_list) - 1
          checklist_1 = Enum.slice(node_list, index_a+1, last_index)
          checklist_2 = Enum.slice(node_list, 0, index_b)
          x in checklist_1 || x in checklist_2
    end
  end

  def real_deal_inclusion(x, a, b) do
    node_list = Chief.get(MyChief)
    cond do
      x == nil ->
        false
      a == b ->
        false
      a < b ->
        index_a = Enum.find_index(node_list, fn(i) -> i==a end)
        index_b = Enum.find_index(node_list, fn(i) -> i==b end)
        check_list = Enum.slice(node_list, index_a+1, index_b-index_a)
        x in check_list
      a > b ->
          index_a = Enum.find_index(node_list, fn(i) -> i==a end)
          index_b = Enum.find_index(node_list, fn(i) -> i==b end)
          last_index = length(node_list) - 1
          checklist_1 = Enum.slice(node_list, index_a+1, last_index)
          checklist_2 = Enum.slice(node_list, 0, index_b + 1)
          x in checklist_1 || x in checklist_2
    end
  end


end