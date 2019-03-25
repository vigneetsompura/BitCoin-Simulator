# block 
# %{
#     :block_number
#     :hash
#     :prev_hash
#     :merkel_root
#     :timestamp
#     :difficulty
#     :nonce
#     :coinbase_transaction
#     [transactions]
# }

defmodule Block do

    def create_block(prev_hash, transactions, difficulty, miner_address, mint_amount) do
        timestamp = DateTime.utc_now()
        coinbase_transaction = Transaction.create_coinbase_transaction(miner_address, mint_amount)
        merkel_root = merkel_root([coinbase_transaction] ++ transactions)
        
        %{
         :prev_hash => prev_hash, 
         :timestamp => timestamp, 
         :merkel_root => merkel_root,
         :difficulty => difficulty, 
         :coinbase_transaction => coinbase_transaction,
         :transactions => transactions
        }
    end

    def merkel_root(transactions) do
        ids = Enum.map(transactions, fn(x)-> 
            Map.get(x, :id)
        end)
        merkel_root_hashes(ids)
    end 
    
    defp merkel_root_hashes(hashes) do
        if(length(hashes) == 1) do
            List.first(hashes)
        else
            merkel_root_hashes(merkel_level([], hashes))
        end
    end

    defp merkel_level(list, hashes) do
        if(hashes != []) do
            [head| tail] = hashes
            first = head

            [head| tail] = if(tail != []) do
                tail
            else 
                [first]
            end
            second = head
            hashes = tail
            merkel_level( list ++ [Crypt.hash256("#{first}#{second}")], hashes)
        else
            list
        end
    end

    def proof_of_work(prev_block, merkel_root, timestamp, difficulty) do
        nonce = Enum.random(0..2147483647*2)
        data = "#{prev_block}#{merkel_root}#{timestamp}#{difficulty}#{nonce}"
        hash = Crypt.hash256(data)
        if (hash<difficulty) do
            {hash, nonce}
        else
            proof_of_work(prev_block,merkel_root, timestamp, difficulty)
        end
    end

    def validate_merkel_root(block) do
        merkel_root = Map.get(block, :merkel_root)
        coinbase_transaction = Map.get(block, :coinbase_transaction)
        transactions = Map.get(block, :transactions)
        merkel_root == merkel_root([coinbase_transaction] ++ transactions)
    end

    def validate_proof_of_work(block)do
        hash = Map.get(block, :hash)
        prev_block = Map.get(block, :prev_hash)
        merkel_root = Map.get(block, :merkel_root)
        timestamp = Map.get(block, :timestamp)
        difficulty = Map.get(block, :difficulty)
        nonce = Map.get(block, :nonce)
        data = "#{prev_block}#{merkel_root}#{timestamp}#{difficulty}#{nonce}"
        hash == Crypt.hash256(data)
    end
end