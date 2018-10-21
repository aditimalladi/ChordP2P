# :observer.start()
[numNodes, numReq] = System.argv

{numNodes, _} = Integer.parse(numNodes)
{numReq, _} = Integer.parse(numReq)

# ets table
IO.inspect data = :ets.new(:data, [:set, :named_table, :public])


{:ok, chief_pid} = Chief.start_link([])
Process.register chief_pid, MyChief

Enum.each(0..numNodes-1, fn(i)->
  {:ok, node_pid} = Peer.start_link(20, data, [])
end)

node_list = Chief.get(MyChief)
first_node = Enum.fetch!(node_list, 0)
IO.puts "First node is #{first_node}"
# node_list = node_list -- [first_node]
first_node_pid = Chief.lookup(MyChief, first_node)

Peer.create(first_node_pid)

Enum.each(1..length(node_list)-1, fn(i)->
  node_pid = Chief.lookup(MyChief, Enum.fetch!(node_list, i))
  Peer.join(node_pid, Enum.fetch!(node_list, i-1))
end)

k = :sys.get_state(chief_pid)
IO.puts "This is the chief state"
IO.inspect k

head = Enum.fetch!(node_list, 0)
tail = Enum.fetch!(node_list, length(node_list)-1)
Peer.set_successor(Chief.lookup(MyChief, tail), head)
Peer.set_predecessor(Chief.lookup(MyChief, head), tail)

:timer.sleep(1000)


# Enum.each(0..numNodes-1, fn(i)->
#   IO.inspect i
#   current_node = Enum.fetch!(node_list, i)
#   [{_, state}] = :ets.lookup(data, current_node)
#   if(state[:id] == state[:succ] || state[:id] == state[:pred]) do
#     IO.inspect state
#   end
# end)

# Enum.each(0..numNodes-1, fn(i)->
#   current_node = Enum.fetch!(node_list, i)
#   node_excl_self = node_list -- [current_node]
#   count = 0
#   Enum.map(0..numReq-1, fn(j)->
#     rand_node = Enum.random(node_excl_self)
#     IO.inspect count = Utils.find_succ_acc(current_node, rand_node, data, 0)
#   end)
# end)

IO.inspect count = Utils.find_succ_acc(head, tail, data, 0)


#:timer.sleep(10000000)