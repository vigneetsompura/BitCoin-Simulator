# state : %{
#     :name => id
#     :blockchain => %{blocks}
#     :neighbours => neighbour miners in the network
#     :transaction_pool => [] Queue for incoming transactions
#     :valid_transactions => UTXOs = 
#         %{
#             "transID/Addr" => output {address, amount}
#         }
#     :current_block => block for proof of work
#     :top_blockchain => block
#     :difficulty
#     :addresses => [{address, public_key, secret_key}] 100 :addresses
#     :utxo => [{transId/addr, addr, amount}]
#     :bounty => 25 edit in add miner function
# }

defmodule Miner do
    use GenServer

    def start(name, state) do
         name = via_tuple(name)
         GenServer.start_link(__MODULE__, state, name: name)
    end

    def init(state) do
        state = Map.put(state, :utxo, [])

        # copy blockchain, top_of_block, :valid_transactions from neighbour if blockchain = nil
        state = if(state.neighbours != []) do
                    Enum.each(state.neighbours, fn(neighbour) -> 
                        GenServer.cast(via_tuple(neighbour), {:add_neighbour, state.name})
                    end)
                    {blockchain, valid_transactions, top_blockchain,difficulty,bounty} = 
                            GenServer.call(via_tuple(Enum.random(state.neighbours)),{:request_blockchain})
                    state = Map.put(state, :blockchain, blockchain)
                    state = Map.put(state, :valid_transactions, valid_transactions)
                    state = Map.put(state, :top_blockchain, top_blockchain)
                    state = Map.put(state, :difficulty, difficulty)
                    state = Map.put(state, :bounty, bounty)
                    state
                else
                    state
                end
        
        # create new block
        {block_transactions, invalid_transations} = fetch_transactions(state.transaction_pool, state.valid_transactions, 5, [])
        state = Map.put(state, :transaction_pool, state.transaction_pool -- invalid_transations)
        {address,_,_} = Enum.random(state.addresses)
        current_block = Block.create_block(state.top_blockchain.hash, block_transactions, state.difficulty, address,state.bounty)
        state = Map.put(state, :current_block, current_block)
        state = Map.put(state, :current_nonce, Enum.random(0..2147483647*2))
        # start proof of work
        #GenServer.cast(self(), {:proof_of_work})
        send(self(), {:proof_of_work})
        update_balance()
        {:ok, state}
    end

    def fetch_transactions(transaction_pool, valid_transactions, num_of_transactions, invalid) do
        transactions = Enum.take(transaction_pool, num_of_transactions)
        invalid_transactions = Enum.reject(transactions, fn(x)-> Transaction.validate_transaction(x, valid_transactions) end)
        if(invalid_transactions == []) do
            {transactions, invalid}
        else
            fetch_transactions(transaction_pool -- invalid_transactions, 
                                     valid_transactions, 
                                     num_of_transactions, invalid ++ invalid_transactions)
        end
    end

    def handle_cast({:add_neighbour, name}, state) do
        state = Map.put(state, :neighbours, state.neighbours ++ [name])
        {:noreply, state}
    end

    # Add new transaction to pending transaction pool
    def handle_cast({:incoming_transaction, transaction}, state) do
        # check if transaction already ecists in a pool
        state = if (Enum.all?(state.transaction_pool, fn(x) -> x != transaction end)) do
                    transaction_pool = state.transaction_pool ++ [transaction]
                    state = Map.put(state, :transaction_pool, transaction_pool)
                    #relay transaction
                    Enum.each(state.neighbours, fn(x)-> 
                        GenServer.cast(via_tuple(x), {:incoming_transaction, transaction})
                    end)
                    state
                else
                    state
                end
        {:noreply, state}
    end

    # SHOW INCOMING BLOCK
    def handle_cast({:incoming_block, block}, state) do
        # get value of state outside if conditions
        arrival_time = System.os_time(:millisecond)
        state = if(Map.has_key?(state.blockchain,block.hash)) do
            state
        else
            state = if (Block.validate_proof_of_work(block) and Block.validate_merkel_root(block) and block.coinbase_transaction.output.amount<=state.bounty) do
                block_transactions = Map.get(block, :transactions)
                correctness_list = Enum.map(block_transactions, fn(x) ->
                    Transaction.validate_transaction(x, Map.get(state, :valid_transactions))
                end)
                state = if(Enum.all?(correctness_list, fn(x)-> x == true end)) do    
                            # valid block
                            # remove transactions in valid block from transactions pool
                            # update top of the blockchain
                            # create new block -> change in state
                            # add new block to the block chain
                            # add transactions in the block to valid_transactions list          
                            # relay the valid block
                            

                            block_number = Map.get(state.blockchain, block.prev_hash).block_number + 1
                            block = Map.put(block, :block_number, block_number)
                            block_map = Map.put(state.block_map, Integer.to_string(block_number), block.hash)
                            state = Map.put(state, :block_map, block_map)

                            #SHOW ACCEPT TRANSACTION
                            Enum.each(block_transactions, fn(t)-> 
                                Project42Web.Endpoint.broadcast! "transaction:#{t.id}" , "transaction_status", %{
                                    status: "Accepted",
                                    block_number:  block_number,
                                    block_hash: block.hash
                                }
                            end)

                            blockchain = Map.put(state.blockchain, block.hash, block)
                            state = Map.put(state, :blockchain, blockchain)
                            state = Map.put(state, :top_blockchain, block)
                            state = Map.put(state, :transaction_pool, state.transaction_pool -- block.transactions)
                            # updating level of difficulty
                            #SHOW DIFFICULTY UPDATE
                            difficulty = if(state.last_block_time != nil) do
                                            time_difference = arrival_time - state.last_block_time
                                            difficulty = state.difficulty
                                            Project42Web.Endpoint.broadcast! "block:#{state.name}" , "new_block", %{
                                                time_to_mine: time_difference,
                                                id: block_number,
                                                hash: block.hash
                                            }
                                            difficulty = if(time_difference > 15000) do
                                                {temp,_} = Integer.parse(difficulty,16)
                                                temp = round(temp*2.5)
                                                String.pad_leading(Integer.to_string(temp,16),64,"0")
                                            else
                                                difficulty
                                            end
                                            difficulty = if(time_difference < 5000) do
                                                {temp,_} = Integer.parse(difficulty,16)
                                                temp = round(temp/2)
                                                String.pad_leading(Integer.to_string(temp,16),64,"0")
                                            else
                                                difficulty
                                            end
                                            
                                            difficulty
                                        else
                                            state.difficulty
                                        end
                            
                            state = Map.put(state, :difficulty, difficulty)
                            state = Map.put(state, :last_block_time, arrival_time)
                            
                            # updating bounty
                            bounty = if(rem(length(Map.keys(state.blockchain)),state.change_rate) == 0) do
                                        state.bounty/2
                                    else
                                        state.bounty
                                    end

                            state = Map.put(state, :bounty, bounty)

                            # remove inputs from valid transactions
                            #SHOW TRANSACTION POOL PICK UP
                            valid_transactions =Map.drop(state.valid_transactions ,List.flatten(
                                                Enum.map(block.transactions, fn(t)-> 
                                                    Enum.map(t.input, fn(i) -> 
                                                        i.prev_transaction
                                                    end)
                                                end)))
                            # add outputs to valid transactions
                            valid_transactions = Enum.into(
                                                    List.flatten(
                                                        Enum.map(block.transactions, fn(t)-> 
                                                            Enum.map(t.output, fn(o) -> 
                                                                {"#{t.id}/#{o.address}", {o.address, o.amount}}
                                                            end)
                                                        end)),valid_transactions)
                            tid = block.coinbase_transaction.id 
                            miner_address = block.coinbase_transaction.output.address
                            bounty = block.coinbase_transaction.output.amount  
                            valid_transactions = Map.put(valid_transactions, "#{tid}/#{miner_address}", {miner_address, bounty})    
                            state = Map.put(state, :valid_transactions, valid_transactions)
                            

                            Enum.each(state.neighbours, fn(x)->
                                GenServer.cast(via_tuple(x), {:incoming_block,block})
                            end)



                            # create new block
                            {block_transactions, invalid_transations} = fetch_transactions(state.transaction_pool, state.valid_transactions, 5, [])
                            state = Map.put(state, :transaction_pool, state.transaction_pool -- invalid_transations)
                            {address,_,_} = Enum.random(state.addresses)
                            current_block = Block.create_block(block.hash, block_transactions, difficulty, address,state.bounty)
                            state = Map.put(state, :current_block, current_block)
                            state = Map.put(state, :current_nonce, Enum.random(0..2147483647*2))
                            state
                        else
                            state
                        end
                state
            else
                state
            end
            state
        end
        
        {:noreply, state}
    end

    #SHOW POW
    def handle_info({:proof_of_work},state) do
        block = state.current_block
        prev_block = block.prev_hash
        merkel_root = block.merkel_root
        timestamp = block.timestamp
        nonce = state.current_nonce
        data = "#{prev_block}#{merkel_root}#{timestamp}#{block.difficulty}#{nonce}"
        hash = Crypt.hash256(data)
        hashval = Integer.parse(hash, 16)
        diffval = Integer.parse(block.difficulty,16)

        state = if (hashval<diffval) do
                    # add to blockchain
                    # relay block
                    block = Map.put(block, :hash, hash)
                    block = Map.put(block, :nonce, nonce)
                    IO.inspect "#{state.name}: mined block <#{block.hash}>, current_chain_length: #{length(Map.keys(state.blockchain))} "
                    block_number = Map.get(state.blockchain, block.prev_hash).block_number + 1
                    block = Map.put(block, :block_number, block_number)
                    block_map = Map.put(state.block_map, Integer.to_string(block_number), hash)
                    state = Map.put(state, :block_map, block_map)

                    #SHOW ACCEPT TRANSACTION
                    Enum.each(block.transactions, fn(t)-> 
                        Project42Web.Endpoint.broadcast! "transaction:#{t.id}" , "transaction_status", %{
                            status: "Accepted",
                            block_number:  block_number,
                            block_hash: block.hash
                        }
                    end)
                    blockchain = state.blockchain
                    blockchain = Map.put(blockchain, block.hash, block)
                    state = Map.put(state, :blockchain, blockchain)
                    state = Map.put(state, :top_blockchain, block)
                    state = Map.put(state, :transaction_pool, state.transaction_pool -- block.transactions)
                    
                    # remove inputs from valid transactions
                    valid_transactions =Map.drop(state.valid_transactions ,List.flatten(
                                        Enum.map(block.transactions, fn(t)-> 
                                            Enum.map(t.input, fn(i) -> 
                                                i.prev_transaction
                                            end)
                                        end)))
                    # add outputs to valid transactions
                    valid_transactions = Enum.into(
                                            List.flatten(
                                                Enum.map(block.transactions, fn(t)-> 
                                                    Enum.map(t.output, fn(o) -> 
                                                        {"#{t.id}/#{o.address}", {o.address, o.amount}}
                                                    end)
                                                end)),valid_transactions)
                    tid = block.coinbase_transaction.id 
                    miner_address = block.coinbase_transaction.output.address
                    bounty = block.coinbase_transaction.output.amount  
                    valid_transactions = Map.put(valid_transactions, "#{tid}/#{miner_address}", {miner_address, bounty})
                    state = Map.put(state, :valid_transactions, valid_transactions)
                    
                    # SHOW RELAY BLOCK                  
                    Enum.each(state.neighbours, fn(x)->
                        GenServer.cast(via_tuple(x), {:incoming_block,block})
                    end)
                    arrival_time = System.os_time(:millisecond)
                    # updating level of difficulty
                
                    
                    difficulty = if(state.last_block_time != nil) do
                                    time_difference = arrival_time - state.last_block_time

                                    Project42Web.Endpoint.broadcast! "block:#{state.name}" , "new_block", %{
                                        time_to_mine: time_difference,
                                        id: block_number,
                                        hash: block.hash
                                    }

                                    difficulty = state.difficulty
                                    difficulty = if(time_difference > 15000) do
                                        {temp,_} = Integer.parse(difficulty,16)
                                        temp = round(temp*2.5)
                                        String.pad_leading(Integer.to_string(temp,16),64,"0")
                                    else
                                        difficulty
                                    end
                                    difficulty = if(time_difference < 5000) do
                                        {temp,_} = Integer.parse(difficulty,16)
                                        temp = round(temp/2)
                                        String.pad_leading(Integer.to_string(temp,16),64,"0")
                                    else
                                        difficulty
                                    end
                                    
                                    difficulty
                                else
                                    state.difficulty
                                end
                    
                    state = Map.put(state, :difficulty, difficulty)
                    state = Map.put(state, :last_block_time, arrival_time)
                    bounty = if(rem(length(Map.keys(state.blockchain)),state.change_rate) == 0) do
                                state.bounty/2
                            else
                                state.bounty
                            end

                    state = Map.put(state, :bounty, bounty)
                    # create new block
                    {block_transactions, invalid_transations} = fetch_transactions(state.transaction_pool, state.valid_transactions, 5, [])
                    state = Map.put(state, :transaction_pool, state.transaction_pool -- invalid_transations)

                    {address,_,_} = Enum.random(state.addresses)
                    current_block = Block.create_block(block.hash, block_transactions, difficulty, address, state.bounty)
                    state = Map.put(state, :current_block, current_block)
                    state = Map.put(state, :current_nonce, Enum.random(0..2147483647*2))

                    state
                else
                    state
                end
        
        state = Map.put(state, :current_nonce, state.current_nonce+1)
        try do 
            Process.send_after(self(), {:proof_of_work}, round(state.pow_delay))
        rescue 
            e in KeyError->
            Process.send_after(self(), {:proof_of_work}, 15)
        end
        #GenServer.cast(self(), {:proof_of_work})
        {:noreply, state}
    end

    def handle_cast({:test}, state) do
        IO.inspect("success")
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

      def handle_cast({:utxo_update, utxo_list,receiver,  reciever_address, amount}, state) do
          if(utxo_list != []) do
            GenServer.cast(self(), {:new_transaction, receiver, reciever_address, amount})
          else
            IO.inspect "No unspent transaction found!"
          end
          state = Map.put(state, :utxo, utxo_list)
          
          {:noreply, state}
      end

      def handle_cast({:retrieve_UTXO, from, receiver, receiver_address, amount, addresses},state) do
        valid_transactions = state.valid_transactions
        keys = Map.keys(valid_transactions)
        valid_keys = Enum.filter(keys, fn(x)-> String.contains?(x, addresses) end)
        utxo_list = Enum.map(valid_keys, fn(x)-> 
            {address, amount} = Map.get(valid_transactions, x)
            {x, address, amount}
        end)
        GenServer.cast(via_tuple(from), {:utxo_update, utxo_list, receiver, receiver_address, amount})
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

    #SHOW REJECT
    def handle_info({:broadcast_reject_id, id},state) do
        Project42Web.Endpoint.broadcast! "transaction:#{id}" , "transaction_status", %{
          status: "Rejected",
          block_number:  0,
          block_hash: 0
        }
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
      GenServer.cast(via_tuple(from), {:utxo_update,id, utxo_list, receiver, receiver_address, amount})
      {:noreply, state}
  end


    def handle_cast({:retrieve_UTXO, from, addresses},state) do
        valid_transactions = state.valid_transactions
        keys = Map.keys(valid_transactions)
        valid_keys = Enum.filter(keys, fn(x)-> String.contains?(x, addresses) end)
        utxo_list = Enum.map(valid_keys, fn(x)-> 
            {address, amount} = Map.get(valid_transactions, x)
            {x, address, amount}
        end)
        GenServer.cast(via_tuple(from), {:utxo_update, utxo_list})
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

    def handle_call({:block_map_request}, _from,  state) do
        start = state.top_blockchain.block_number
        blocks = 
            Enum.map(start..start-19, fn(i) -> {i, Map.get(state.block_map, Integer.to_string(i))} end) 
            |> Enum.reject(fn({_,n}) -> n == nil end)
        {:reply, blocks, state}
    end

    def handle_call({:get_block, id}, _from, state) do
        block_hash = Map.get(state.block_map, id)
        block = Map.get(state.blockchain, block_hash)
        {:reply, block, state}
    end

    def handle_info(:update_utxo, state) do
        GenServer.cast(via_tuple(Enum.random(state.neighbours)), {:retrieve_UTXO, state.name, Enum.map(state.addresses, fn({x,_y,_z})-> x end)})
        {:noreply, state}
    end

    def handle_call({:miner_status}, _from, state) do
        {:reply, {state.top_blockchain,length(Map.keys(state.blockchain)), length(Map.keys(state.valid_transactions)), state.difficulty, length(state.transaction_pool), state.bounty}, state}
    end

    def handle_call({:get_balance}, _from, state) do
        {:reply, Enum.sum(Enum.map(state.utxo, fn({_,_,amount})-> amount end)), state}
    end

    def handle_call({:get_last_block}, _from, state) do
        {:reply, state.top_blockchain, state}
    end

    def handle_call({:request_blockchain}, _from, state) do
        blockchain = state.blockchain
        valid_transactions = state.valid_transactions
        top_blockchain = state.top_blockchain
        difficulty = state.difficulty
        bounty = state.bounty
        {:reply, {blockchain, valid_transactions, top_blockchain, difficulty, bounty}, state}
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

    def update_balance() do
        Process.send_after(self(), :update_utxo, 1000)    
    end

    defp via_tuple(id) do
        {:via, Registry, {:process_registry, id}}
    end
end