# :observer.start()
Process.register self(), Main
[numNodes, numReq] = System.argv

{numNodes, _} = Integer.parse(numNodes)
{numReq, _} = Integer.parse(numReq)


{chief_pid, :ok} = Chief.start_link([])
Process.register chief_pid, MyChief

Enum.each(0..numNodes-1, fn(i)->
  {node_pid, :ok} = NwNode.start_link([])
  Chief.update_kash(chief_pid, Utils.hash_modulus(node_pid), node_pid)
  Chief.put(chief_pid, Utils.hash_modulus(node_pid))
end)

