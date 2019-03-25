# Galleon

Team Members:
-------------
Vigneet Sompura  
Venkatalakshmisupraja Keerthikaushal Gudur  

Description:
------------
The poject is a simulation of the bitcoin protocol. It implements wallets, performs transactions between users and mine blocks that constitute the blockchain. A web interface has been implemented for the same that accepts the configuration for the system, displays the status of it by showing various charts that depecit the current status of the system.

Bonus question:
---------------
A transaction can also be made from the web application. Depending on whether the trasaction is accepted or not, a status update is given to the user.

Simulation steps for 4.1:
-------------------------
-> Navigate to the root directory of the project in command prompt  
-> run the following command for compiling the code:  
    iex -S mix  
-> Initialize the network using one of the following functions:  
    Galleon.start(difficulty, number_of_miners, number_of_wallets) // to create a network of specified number of miners and non-miners. Difficulty refers to the minimum number of leading zeros in the hash code of a block.  
    Galleon.start(difficulty,number_of_miners) // to create a network of specified number of miners.  
    Galleon.start(difficulty) // to create a network of 5 miners by default.  
-> Use the following functions for the specified functionality:  
    •	Galleon.status() – to see the current values of numbers of miners, number of non-miners(nodes that act only as a wallet and not as a miner), total number of nodes in the network, hash ID of the last block added to blockchain, current length of blockchain and total unspent transactions overall.  
    •	Galleon.transact(number_of_transactions) – performs the specified number of transactions between wallets.  
    •	Galleon.transact(sender,receiver,amount) – creates a transaction between the sender and receiver with the specified amount.  
            The sender and receiver are numeric IDs of nodes between 0 to num_nodes-1  
    •	Galleon.add_miner() – adds 1 additional miner to the network  
    •	Galleon.add_miners(number) – adds the specified number of miners to the network.  
    •	Galleon.add_wallet() – adds 1 additional non-miner to the network  
    •	Galleon.add_wallets (number) – adds the specified number of non-miners to the network.  
    •	Galleon.show_balance(node_ID) – displays the balance available in the wallet of the specified node(a number between 0 and num_nodes-1).  
    •	Galleon.die – to halt all the processes  
-> Run the following command to run test cases on the code:  
    mix run test\galleon_test.exs  
    The test cases mentioned in galleon_test.exs check that:  
    •	The network is created with the given specifications   
    •	Checks balances of nodes after performing transactions on them  
    •	Checks proof-of-work and correctness of merkel-root of a block present in the chain.  
    
Simulation steps for part 4.2:
-------------------------------
•	From command prompt, navigate to inside the project folder. There enter the following command: iex -S mix phx.server  
•	In your browser, open localhost:4000  
•	The first page is the configuration page. We call the application Galleon which is what currency is called in Harry Potter. This page accepts inputs based on which the system is tested. Upon clicking “confirm”, the router directs the flow to the dashboard_controller that starts the main program through the function Galleon.start with the given inputs.  
•	From here, you are redirected to the dashboard page that shows the current stats of the system.  
•	The rewards miners win for mining a block are halved for every certain number(provided as input) to the blockchain. This is to make sure that the total number of galleons in the system are limited(as in the actual bitcoin system).  


Bonus question implementation:
------------------------------
•	There is a feature to make transactions in the application by specifying the sender, receiver and the amounts.   
•	The status of this transaction is shown. To test this feature, provide the sender, receiver and amount to be transacted. If the transaction is valid, as in the sender has so many unspent UTXOs, it is accepted. When it is included in a block, a status is broadcasted to the channel that it is accepted along with the block that contains the transaction. It is possible to navigate to this block and check if the transaction is actually present in it.  
•	If the transaction is rejected because of reasons like insufficient funds at the sender, the same is broadcasted.  

