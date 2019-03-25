defmodule App do
  use Application

  def start(_,_) do
  end

  def start() do
      import Supervisor.Spec, warn: false

      children = [
          worker(Registry, [:unique, :process_registry])
      ]

      opts = [strategy: :one_for_one, name: App.Supervisor]
      Supervisor.start_link(children, opts)
  end

  def via_tuple(id) do
    {:via, Registry, {:process_registry, id}}
  end

end

# state{
#   :difficulty  => Base.encode16(:binary.encode_unsigned(round(:math.pow(16,64-difficulty))))
#   :miners => list of :miners
#   :number_of_miners => miners
#   :genesis_block => block
#   :number_of_nodes => nodes initially 0
#   :wallet_addresses => %{process_name =>[addresses]}
# }

defmodule Galleon do
  use GenServer

  def start(num_miners, num_wallets, initial_rewards,
              max_miners, add_min_miners, add_max_miners, add_miner_delay,
                add_min_transactions, add_max_transactions, add_transaction_delays, reward_change_rate) do
    #App.start()
    args = {2, num_miners, num_wallets,initial_rewards,
      max_miners, add_min_miners, add_max_miners, add_miner_delay,
        add_min_transactions, add_max_transactions, add_transaction_delays, reward_change_rate}
    GenServer.start_link(__MODULE__, args, name: via_tuple("server"))
  end

  def init(state) do
    {difficulty,num_miners, num_wallets, initial_rewards, max_miners,
      add_min_miners, add_max_miners, add_miner_delay,
        add_min_transactions, add_max_transactions, add_transaction_delays,
        reward_change_rate} = state
    difficulty = String.pad_leading(Base.encode16(:binary.encode_unsigned(round(:math.pow(16,64-difficulty)))),64,"0")
    #create Genesis Block
    prev_hash = Crypt.hash256("bitcoin")
    merkel_root = Crypt.hash256("0")
    timestamp = DateTime.utc_now()
    genesis_block = %{
      :prev_hash => prev_hash,
      :merkel_root => merkel_root,
      :timestamp => timestamp,
      :block_number => 0,
      :difficulty => difficulty,
      :nonce => 0,
      :hash => Crypt.hash256("#{prev_hash}#{merkel_root}#{timestamp}#{difficulty}0"),
      :transactions => []

    }
    #create miners
    add_miners(num_miners)
    #create wallets
    if(num_wallets != 0) do
      add_wallets(num_wallets)
    end

    state = %{:difficulty => difficulty, :genesis_block => genesis_block, :miners => [],
     :add_min_miners => add_min_miners, :add_max_miners => add_max_miners, :add_miner_delay => add_miner_delay,
     :add_min_transactions => add_min_transactions, :add_max_transactions => add_max_transactions, :add_transaction_delays => add_transaction_delays,
     :max_miners => max_miners, :number_of_miners=>0, :number_of_nodes=>0, :wallet_addresses=>%{},
     :bounty => initial_rewards ,:reward_change_rate=>reward_change_rate, :main_miner => 0}
    Process.send_after(self(), {:broadcast_status}, 1000)
    Process.send_after(self(), {:add_transactions_randomly}, add_transaction_delays)
    {:ok, state}
  end

  def broadcast_status(time) do
    Process.send_after(self(), {:broadcast_status}, time)
  end

  # SHOW ADD MINER
  # .................... add_miner handle cast change...............
  def handle_cast({:add_miners, num_miners}, state) do
    state =
    if(state.number_of_miners + num_miners <= state.max_miners) do
      # IO.puts "miners count acceptable #{state.number_of_miners + num_miners}"
      miners_data = Enum.map(state.number_of_nodes..state.number_of_nodes+num_miners-1, fn(id)->
        blockchain = %{state.genesis_block.hash => state.genesis_block}
        neighbours = Enum.reject([0] ++
                                Enum.take_random(state.miners ++ Enum.to_list(state.number_of_nodes..id),
                                Enum.random(3..length(state.miners))),fn(x)-> x==id end)
        top_blockchain = state.genesis_block
        difficulty = state.difficulty
        bitcoin_addresses = Enum.map(1..10, fn(_) -> Crypt.generate_bitcoin_address() end)
        miner_state = %{
                  :name => id,
                  :blockchain => blockchain,
                  :neighbours => neighbours,
                  :transaction_pool => [],
                  :current_block => nil,
                  :valid_transactions => %{},
                  :top_blockchain => top_blockchain,
                  :difficulty => difficulty,
                  :last_block_time => nil,
                  :addresses => bitcoin_addresses,
                  :bounty => state.bounty,
                  :change_rate =>state.reward_change_rate,
                  :pow_delay => state.max_miners/4,
                  :block_map => %{Integer.to_string(0) => state.genesis_block.hash}
                }
        #IO.puts "Miner Started :#{id}"
        #IO.inspect "diff #{difficulty}"
        Miner.start(id, miner_state)

        addresses = Enum.map(bitcoin_addresses, fn({x,_y,_z})-> x end)
        {id, addresses}
      end)

      state = Map.put(state, :number_of_miners, state.number_of_miners+num_miners)
      state = Map.put(state, :number_of_nodes, state.number_of_nodes+num_miners)
      wallet_addresses = Enum.into(miners_data, state.wallet_addresses)
      state = Map.put(state, :wallet_addresses, wallet_addresses)
      state = Map.put(state, :miners, state.miners ++ Enum.map(miners_data, fn({x,_y})-> x end))
      IO.inspect "#{num_miners} new miners started"
      Process.send_after(self(), {:add_miners_randomly}, state.add_miner_delay)
      state
    else
      possible_miner_addition = num_miners - (state.number_of_miners+num_miners - state.max_miners)
      state =
      if(possible_miner_addition == 0) do
        #IO.puts "Miners limit reached! Cannot add additional miners"
        state
      else
        #IO.puts "#{state.max_miners}"
        #IO.inspect "Maximum miners in the system cannot exceed #{state.max_miners}"
        #IO.inspect "Adding only #{possible_miner_addition} miners of the requested #{num_miners}"
        miners_data = Enum.map(state.number_of_nodes..state.number_of_nodes+possible_miner_addition-1, fn(id)->
          blockchain = %{state.genesis_block.hash => state.genesis_block}
          neighbours = Enum.reject([0] ++ Enum.take_random(state.miners ++ Enum.to_list(state.number_of_nodes..id),Enum.random(3..length(state.miners))),fn(x)-> x==id end)
          top_blockchain = state.genesis_block
          difficulty = state.difficulty
          bitcoin_addresses = Enum.map(1..10, fn(_) -> Crypt.generate_bitcoin_address() end)
          miner_state = %{
                    :name => id,
                    :blockchain => blockchain,
                    :neighbours => neighbours,
                    :transaction_pool => [],
                    :current_block => nil,
                    :valid_transactions => %{},
                    :top_blockchain => top_blockchain,
                    :difficulty => difficulty,
                    :last_block_time => nil,
                    :addresses => bitcoin_addresses,
                    :bounty => state.bounty,
                    :change_rate =>state.reward_change_rate,
                    :pow_delay => state.max_miners/4,
                    :block_map => %{Integer.to_string(0) => state.genesis_block.hash}
                  }
          #IO.puts "Miner Started :#{id}"
          #IO.inspect "diff #{difficulty}"
          Miner.start(id, miner_state)

          addresses = Enum.map(bitcoin_addresses, fn({x,_y,_z})-> x end)
          {id, addresses}
        end)

        state = Map.put(state, :number_of_miners, state.number_of_miners+possible_miner_addition)
        state = Map.put(state, :number_of_nodes, state.number_of_nodes+possible_miner_addition)
        wallet_addresses = Enum.into(miners_data, state.wallet_addresses)
        state = Map.put(state, :wallet_addresses, wallet_addresses)
        state = Map.put(state, :miners, state.miners ++ Enum.map(miners_data, fn({x,_y})-> x end))
        #IO.inspect "#{possible_miner_addition} new miners started"
        state
      end
      state
    end
    {:noreply, state}
  end

  # SHOW ADD WALLET
  def handle_cast({:add_wallets, num_wallets}, state) do
    wallet_data = Enum.map(state.number_of_nodes..state.number_of_nodes+num_wallets-1, fn(id)->

      neighbours = Enum.take_random(state.miners,Enum.random(3..length(state.miners)))
      bitcoin_addresses = (1..10)|> Enum.map(fn(_) -> Crypt.generate_bitcoin_address() end)
      wallet_state = %{
                :name => id,
                :neighbours => neighbours,
                :addresses => bitcoin_addresses
              }
      Wallet.start(id, wallet_state)
      addresses = Enum.map(bitcoin_addresses, fn({x,_y,_z})-> x end)
      {id, addresses}
    end)

    state = Map.put(state, :number_of_nodes, state.number_of_nodes+num_wallets)
    wallet_addresses = Enum.into(wallet_data, state.wallet_addresses)
    state = Map.put(state, :wallet_addresses, wallet_addresses)
    IO.inspect "#{num_wallets} new wallets(non-miners) started"
    {:noreply, state}
  end

   #SHOW BROADCAST STATUS
   def handle_info({:broadcast_status}, state) do
    try do
      {last_block, length_blockchain, length_utxo, target, pool_size, bounty} = GenServer.call(via_tuple(state.main_miner), {:miner_status})
      {temp,_} = Integer.parse(target,16)
      difficulty = round(:math.pow(16,64)/temp)
  
      Project42Web.Endpoint.broadcast! "status:0" , "new_status", %{
        miners: state.number_of_miners,
        wallets: state.number_of_nodes - state.number_of_miners,
        nodes: state.number_of_nodes,
        lastblock: last_block.hash,
        chainlength: length_blockchain,
        utxo: length_utxo,
        difficulty: difficulty,
        target: String.pad_leading(target,64,"0"),
        pool_size: pool_size,
        bounty: bounty,
        total_coins: coins_mined(length_blockchain, state.bounty, state.reward_change_rate)
      }
      Process.send_after(self(), {:broadcast_status}, 5000)
    catch
      :exit, _ -> IO.puts "caught exit"
      GenServer.cast(self(), {:change_main_miner});
      Process.send_after(self(), {:broadcast_status}, 5000)  
    end
    {:noreply, state}
  end


  def handle_info({:add_miners_randomly},state) do
    #IO.puts "------now adding miners randomly-----"
    num_miners = Enum.random(state.add_min_miners..state.add_max_miners)
    GenServer.cast(via_tuple("server"),{:add_miners, num_miners})
    {:noreply, state}
  end
  # # .................... add_miner handle cast change...............

  

  # ................................transact changed ........................
  def handle_cast({:transact, num},state) do
    {_, length_blockchain, _,_,_,_} = GenServer.call(via_tuple(Enum.random(state.miners)), {:miner_status})
    if(length_blockchain>10) do
      Enum.each(1..num, fn(_) ->
        sender = Enum.random(0..state.number_of_nodes-1)
        receiver = Enum.random(0..state.number_of_nodes-1)
        receiver_address = Enum.random(Map.get(state.wallet_addresses, receiver))
        amount = Enum.random(0..10)
        GenServer.cast(via_tuple(sender), {:new_transaction, receiver, receiver_address, amount})
      end)
    end
    Process.send_after(self(), {:add_transactions_randomly}, state.add_transaction_delays)
    {:noreply,state}
  end

  def handle_info({:add_transactions_randomly}, state) do
    num = Enum.random(state.add_min_transactions..state.add_max_transactions)
    GenServer.cast(self(),{:transact, num})
    {:noreply, state}
  end
  # ................................transact changed ........................


   #SHOW TRANSACT
  def handle_cast({:transact, id, sender, receiver, amount},state) do
      receiver_address = Enum.random(Map.get(state.wallet_addresses, receiver))
      GenServer.cast(via_tuple(sender), {:new_transaction, id, receiver, receiver_address, amount})
    {:noreply,state}
  end


  def handle_cast({:network_status}, state) do
    {last_block, length_blockchain, length_utxo, _,_,_} = GenServer.call(via_tuple(Enum.random(state.miners)), {:miner_status})
    IO.puts "No. of miners              : #{state.number_of_miners}"
    IO.puts "No. of non miners          : #{state.number_of_nodes - state.number_of_miners}"
    IO.puts "Total Nodes in Network     : #{state.number_of_nodes}"
    IO.puts "Hash of last block         : #{last_block.hash}"
    IO.puts "Length of blockchain       : #{length_blockchain}"
    IO.puts "Total unspent transactions : #{length_utxo}"
    {:noreply, state}
  end

  def handle_cast({:change_main_miner},state) do
    state = Map.put(state, :main_miner, Enum.random(state.miners))
    {:noreply, state}
  end


 

  def coins_mined(length, bounty, rate_of_change) do
    coins = 
      if (length>rate_of_change) do
        rate_of_change*bounty + coins_mined(length-rate_of_change, bounty/2, rate_of_change)
      else
        length*bounty
      end
  end

  def add_miners(num_miners) do
    GenServer.cast(via_tuple("server"), {:add_miners, num_miners})
  end

  def transact(num) do
    GenServer.cast(via_tuple("server"),{:transact, num})
  end


 
  def transact(sender, receiver, amount) do
    id = Crypt.hash256("#{DateTime.utc_now}")
    GenServer.cast(via_tuple("server"),{:transact, id, sender, receiver, amount})
    id
  end

  def add_miner() do
    GenServer.cast(via_tuple("server"), {:add_miners, 1})
  end

  def add_wallets(num_wallets) do
    GenServer.cast(via_tuple("server"), {:add_wallets, num_wallets})
  end

  def add_wallet() do
    GenServer.cast(via_tuple("server"), {:add_wallets, 1})
  end

  def status() do
    GenServer.cast(via_tuple("server"), {:network_status})
  end

  def die() do
    Process.exit(self(), :normal)
  end

  def show_balance(node) do
    IO.puts("Balance of node #{node}:#{GenServer.call(via_tuple(node), {:get_balance})}")
  end

  def balance(node) do
    GenServer.call(via_tuple(node), {:get_balance})
  end

  def block_map() do
    GenServer.call(via_tuple(0), {:block_map_request})
  end

  def get_block(id) do
    GenServer.call(via_tuple(0), {:get_block, id})
  end

  def last_block(miner) do
    GenServer.call(via_tuple(miner), {:get_last_block})
  end

  defp via_tuple(id) do
    {:via, Registry, {:process_registry, id}}
  end

    # ..................old add_miners..............
  # def handle_cast({:add_miners, num_miners}, state) do

  #   miners_data = Enum.map(state.number_of_nodes..state.number_of_nodes+num_miners-1, fn(id)->
  #     blockchain = %{state.genesis_block.hash => state.genesis_block}
  #     neighbours = Enum.reject([0] ++ Enum.take_random(state.miners ++ Enum.to_list(state.number_of_nodes..id),Enum.random(3..length(state.miners))),fn(x)-> x==id end)
  #     top_blockchain = state.genesis_block
  #     difficulty = state.difficulty
  #     bitcoin_addresses = Enum.map(1..10, fn(_) -> Crypt.generate_bitcoin_address() end)
  #     miner_state = %{
  #               :name => id,
  #               :blockchain => blockchain,
  #               :neighbours => neighbours,
  #               :transaction_pool => [],
  #               :current_block => nil,
  #               :valid_transactions => %{},
  #               :top_blockchain => top_blockchain,
  #               :difficulty => difficulty,
  #               :last_block_time => nil,
  #               :addresses => bitcoin_addresses,
  #               :bounty => state.bounty,
  #               :change_rate =>state.reward_change_rate
  #             }
  #     #IO.puts "Miner Started :#{id}"
  #     IO.inspect "diff #{difficulty}"
  #     Miner.start(id, miner_state)

  #     addresses = Enum.map(bitcoin_addresses, fn({x,_y,_z})-> x end)
  #     {id, addresses}
  #   end)

  #   state = Map.put(state, :number_of_miners, state.number_of_miners+num_miners)
  #   state = Map.put(state, :number_of_nodes, state.number_of_nodes+num_miners)
  #   wallet_addresses = Enum.into(miners_data, state.wallet_addresses)
  #   state = Map.put(state, :wallet_addresses, wallet_addresses)
  #   state = Map.put(state, :miners, state.miners ++ Enum.map(miners_data, fn({x,_y})-> x end))
  #   IO.inspect "#{num_miners} new miners started"

  #   {:noreply, state}
  # end

    # .................old :transact............
  # def handle_cast({:transact, num},state) do
  #   Enum.each(1..num, fn(_) ->
  #     sender = Enum.random(0..state.number_of_nodes-1)
  #     receiver = Enum.random(0..state.number_of_nodes-1)
  #     receiver_address = Enum.random(Map.get(state.wallet_addresses, receiver))
  #     amount = Enum.random(0..10)
  #     GenServer.cast(via_tuple(sender), {:new_transaction, receiver, receiver_address, amount})
  #   end)
  #   {:noreply,state}
  # end
end
