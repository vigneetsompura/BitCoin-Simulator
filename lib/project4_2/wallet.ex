# state= %{
#   :name => id
#   :neighbours => *miners only
#   :addresses => [{address, public_key, secret_key}] 100 :addresses
#   :utxo => [{transId/addr, addr, amount}]
# }


defmodule Wallet do
  use GenServer

  def start(name, state) do
    name = via_tuple(name)
    GenServer.start_link(__MODULE__, state, name: name)
  end

  def init(state) do
    state = Map.put(state, :utxo, [])
    update_balance()
    {:ok, state}
  end

  def update_balance() do
    Process.send_after(self(), :update_utxo, 1000)    
  end
  
  def handle_info(:update_utxo, state) do
    GenServer.cast(via_tuple(Enum.random(state.neighbours)), {:retrieve_UTXO, state.name, Enum.map(state.addresses, fn({x,_y,_z})-> x end)})
    {:noreply, state}
  end

  def handle_cast({:utxo_update, utxo_list}, state) do
    state = Map.put(state, :utxo, utxo_list)
    update_balance()
    GenServer.cast(self(), {:broadcast_balance})
    {:noreply, state}
  end

  def handle_cast({:broadcast_balance}, state) do
    balance = Enum.sum(Enum.map(state.utxo, fn({_,_,amount})-> amount end))
    Project42Web.Endpoint.broadcast! "wallet:#{state.name}" , "new_balance", %{
      id: state.name,
      balance: balance,
    }
    {:noreply, state}
  end

  def handle_cast({:new_transaction, receiver, reciever_address, amount},state) do
    # create transaction
    state = if(state.utxo == []) do                
              address_list = Enum.map(state.addresses, fn({x,_y,_z})-> x end)
              GenServer.cast(via_tuple(Enum.random(state.neighbours)), {:retrieve_UTXO, state.name, receiver, reciever_address, amount, address_list})
              state
            else
              input_list = fetch_inputs(amount, state.utxo, [])
              state =if(input_list != []) do
                        input_sum = Enum.sum(Enum.map(input_list, fn({_,_,amt})-> amt end))
                        inputs = Enum.map(input_list, fn({id,addr,amt})-> 
                                  {_, public_key, secret_key} = Enum.at(
                                    Enum.filter(state.addresses, 
                                    fn({ad,_,_})-> 
                                      addr==ad 
                                    end),0)
                                  %{
                                    :prev_transaction => id,
                                    :amount => amt,
                                    :public_key => public_key,
                                    :signature => Crypt.sign_input(public_key, secret_key)
                                  }
                                end)
                        outputs =  if(input_sum > amount) do
                                    {change_address,_,_} = Enum.random(state.addresses)
                                    [%{:address => reciever_address, :amount=>amount},
                                    %{:address => change_address, :amount=>input_sum-amount}
                                    ]
                                  else
                                    [%{:address => reciever_address, :amount=>amount}]
                                  end
                        transaction = Transaction.create_transaction(inputs,outputs)
                        GenServer.cast(via_tuple(Enum.random(state.neighbours)), {:incoming_transaction, transaction})
                        IO.puts "#{state.name} sent #{amount} coins to #{receiver}"
                        state = Map.put(state, :utxo, state.utxo -- input_list)
                        state
                    else
                      IO.inspect "Not enough balance!"
                      state
                    end
              state
            end
    {:noreply,state}
  end

  # SHOW_NEW_TRANSACTION
  def handle_cast({:new_transaction, id, receiver, reciever_address, amount},state) do
    # create transaction
    state = if(state.utxo == []) do                
              address_list = Enum.map(state.addresses, fn({x,_y,_z})-> x end)
              GenServer.cast(via_tuple(Enum.random(state.neighbours)), {:retrieve_UTXO, id, state.name, receiver, reciever_address, amount, address_list})
              state
            else
              input_list = fetch_inputs(amount, state.utxo, [])
              state =if(input_list != []) do
                        input_sum = Enum.sum(Enum.map(input_list, fn({_,_,amt})-> amt end))
                        inputs = Enum.map(input_list, fn({id,addr,amt})-> 
                                  {_, public_key, secret_key} = Enum.at(
                                    Enum.filter(state.addresses, 
                                    fn({ad,_,_})-> 
                                      addr==ad 
                                    end),0)
                                  %{
                                    :prev_transaction => id,
                                    :amount => amt,
                                    :public_key => Base.encode16(public_key),
                                    :signature => Base.encode16(Crypt.sign_input(public_key, secret_key))
                                  }
                                end)
                        outputs =  if(input_sum > amount) do
                                    {change_address,_,_} = Enum.random(state.addresses)
                                    [%{:address => reciever_address, :amount=>amount},
                                    %{:address => change_address, :amount=>input_sum-amount}
                                    ]
                                  else
                                    [%{:address => reciever_address, :amount=>amount}]
                                  end
                        transaction =  %{:id => id,
                                            :input =>inputs,
                                            :output =>outputs
                                        }
                        GenServer.cast(via_tuple(Enum.random(state.neighbours)), {:incoming_transaction, transaction})
                        IO.puts "#{state.name} sent #{amount} coins to #{receiver}"
                        state = Map.put(state, :utxo, state.utxo -- input_list)
                        state
                    else
                        Process.send_after(self(),{:broadcast_reject_id, id},5000)
                      state
                    end
              state
            end
    {:noreply,state}
  end

  def handle_info({:broadcast_reject_id, id},state) do
    Project42Web.Endpoint.broadcast! "transaction:#{id}" , "transaction_status", %{
      status: "Rejected",
      block_number:  0,
      block_hash: 0
    }
    {:noreply, state}
  end
  
  def handle_cast({:utxo_update, utxo_list, receiver, reciever_address, amount}, state) do
      if(utxo_list != []) do
        GenServer.cast(self(), {:new_transaction, receiver, reciever_address, amount})
      else
        IO.inspect "No unspent transaction found!"
      end
      state = Map.put(state, :utxo, utxo_list)
      {:noreply, state}
  end

  def handle_cast({:utxo_update, id, utxo_list,receiver,  reciever_address, amount}, state) do
    if(utxo_list != []) do
      GenServer.cast(self(), {:new_transaction, receiver, reciever_address, amount})
    else
      Process.send_after(self(),{:broadcast_reject_id, id},5000)
    end
    state = Map.put(state, :utxo, utxo_list)
    
    {:noreply, state}
end

def handle_cast({:retrieve_UTXO, id, from, receiver, receiver_address, amount, addresses},state) do
  valid_transactions = state.valid_transactions
  keys = Map.keys(valid_transactions)
  valid_keys = Enum.filter(keys, fn(x)-> String.contains?(x, addresses) end)
  utxo_list = Enum.map(valid_keys, fn(x)-> 
      {address, amount} = Map.get(valid_transactions, x)
      {x, address, amount}
  end)
  GenServer.cast(via_tuple(from), {:utxo_update, id, utxo_list, receiver, receiver_address, amount})
  {:noreply, state}
end
  
  def handle_call({:get_balance}, _from, state) do
    {:reply, Enum.sum(Enum.map(state.utxo, fn({_,_,amount})-> amount end)), state}
  end

  def fetch_inputs(amount, _, current_list) when amount<=0 do
    current_list
  end

  def fetch_inputs(amount, utxo, current_list) when amount>0 do
    if(utxo != []) do
      [head|tail] = utxo
      {_, _, amt} = head
      fetch_inputs(amount-amt, tail, current_list++[head])
    else
      [{"F/F", "F", 1000000}]
    end
  end

  defp via_tuple(id) do
    {:via, Registry, {:process_registry, id}}
  end


  
end
