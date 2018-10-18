:observer.start()
[numNodes, numReq] = System.argv

{numNodes, _} = Integer.parse(numNodes)
{numReq, _} = Integer.parse(numReq)


{:ok, chief_pid} = Chief.start_link([])
Process.register chief_pid, MyChief

Enum.each(0..numNodes-1, fn(i)->
  {:ok, node_pid} = Peer.start_link(10, [])
  Chief.update_kash(chief_pid, Utils.hash_modulus(node_pid), node_pid)
  Chief.put(chief_pid, Utils.hash_modulus(node_pid))
end)

node_list = Chief.get(MyChief)

:timer.sleep(1000)

first_node = Enum.fetch!(node_list, 0)
IO.puts "First node is #{first_node}"
node_list = node_list -- [first_node]
first_node_pid = Chief.lookup(MyChief, first_node)

Peer.create(first_node_pid)

Enum.each(node_list, fn(node)->
  node_list
  node_pid = Chief.lookup(MyChief, node)
  Peer.join(node_pid, first_node)
end)


:timer.sleep(10000000)