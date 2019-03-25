# transaction: %{
#     :id => hash of the transaction
#     :input => [
#         %{
#             :prev_transaction => Transactionhash/Address   
#             :amount => amount of bitcoins
#             :public_key => public_key to verify signature
#             :signature => signature generated with :prev_hash, :output_index, :amount
#         }
#     ]
    
#     :output => [
#         ${
#             :address => address of receiver
#             :amount => received amount 
#         }
#     ]
# }

defmodule Transaction do

    def create_transaction(input, output) do
        try do
            input_string = List.to_string(Enum.map(List.flatten(
                Enum.map(input, fn(x)-> "#{Map.values(x)}" end)), fn(y) -> "#{y}" end))
            #IO.inspect "--------------------------------------------------------------------------------------------"
            #IO.inspect Enum.map(List.flatten(Enum.map(input, fn(x)-> "#{Map.values(x)}" end)), fn(y) -> "#{y}" end)
            #IO.inspect "--------------------------------------------------------------------------------------------"
            output_string = List.to_string(Enum.map(List.flatten(
                Enum.map(output, fn(x)-> Map.values(x) end)), fn(y) -> "#{y}" end))
            id = Crypt.hash256("#{DateTime.utc_now}#{input_string}#{output_string}")
            %{:id => id,
            :input => input,
            :output => output}
        rescue
            e in ArgumentError -> 
            id = Crypt.hash256("#{DateTime.utc_now}")
            %{:id => id,
              :input =>input,
              :output =>output
            }
        end
    end

    def create_coinbase_transaction(output_address,amount) do
        id = Crypt.hash256("#{DateTime.utc_now}#{output_address}#{amount}")
        %{:id => id,
          :output => %{:address => output_address, :amount=> amount}
        }
    end

    def validate_address(address, public_key) do
        address == Crypt.generate_bitcoin_address(public_key) 
    end

    # validate single transaction
    def validate_transaction(transaction, transactions) do
        input = Map.get(transaction, :input) 
        correctness_list = Enum.map(input, fn(x)-> 
           prev_transaction = Map.get(transactions, Map.get(x, :prev_transaction))
            if(prev_transaction != nil) do
                # verify amounts, address and signature
                {address,amount} = prev_transaction
                ( amount == Map.get(x, :amount) 
                    and validate_address(address, Map.get(x,:public_key))
                    and Crypt.verify_input_signature(x)) 
            else
                false
            end
        end)
        input_sum = Enum.sum(Enum.map(input, fn(x)-> x.amount end))
        output_sum = Enum.sum(Enum.map(transaction.output, fn(x)-> x.amount end))

        ((input_sum >= output_sum) and (Enum.any?(correctness_list, fn(x)-> x==false end)))
    end


end