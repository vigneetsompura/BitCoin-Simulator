// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// To use Phoenix channels, the first step is to import Socket,
// and connect at the socket path in "lib/web/endpoint.ex".
//
// Pass the token on params as below. Or remove it
// from the params if you are not using authentication.
import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

// When you connect, you'll often need to authenticate the client.
// For example, imagine you have an authentication plug, `MyAuth`,
// which authenticates the session and assigns a `:current_user`.
// If the current user exists you can assign the user's token in
// the connection for use in the layout.
//
// In your "lib/web/router.ex":
//
//     pipeline :browser do
//       ...
//       plug MyAuth
//       plug :put_user_token
//     end
//
//     defp put_user_token(conn, _) do
//       if current_user = conn.assigns[:current_user] do
//         token = Phoenix.Token.sign(conn, "user socket", current_user.id)
//         assign(conn, :user_token, token)
//       else
//         conn
//       end
//     end
//
// Now you need to pass this token to JavaScript. You can do so
// inside a script tag in "lib/web/templates/layout/app.html.eex":
//
//     <script>window.userToken = "<%= assigns[:user_token] %>";</script>
//
// You will need to verify the user token in the "connect/3" function
// in "lib/web/channels/user_socket.ex":
//
//     def connect(%{"token" => token}, socket, _connect_info) do
//       # max_age: 1209600 is equivalent to two weeks in seconds
//       case Phoenix.Token.verify(socket, "user socket", token, max_age: 1209600) do
//         {:ok, user_id} ->
//           {:ok, assign(socket, :user, user_id)}
//         {:error, reason} ->
//           :error
//       end
//     end
//
// Finally, connect to the socket:
socket.connect()

// Now that you are connected, you can join channels with a topic:

const createSocket = (walletId) =>{
  let channel = socket.channel(`wallet:${walletId}`, {})
  channel.join()
    .receive("ok", resp => { console.log("Joined successfully", resp) })
    .receive("error", resp => { console.log("Unable to join", resp) })

  channel.on('new_balance', msg => {
    console.log("id"+msg.id+"balance"+msg.balance)
    document.getElementById('id').innerHTML = msg.id
    document.getElementById('balance').innerHTML = msg.balance
  })
}

const createBlockSocket = () =>{
  let channel = socket.channel(`block:0`, {})
  channel.join()
    .receive("ok", resp => { console.log("Joined successfully", resp) })
    .receive("error", resp => { console.log("Unable to join", resp) })

  channel.on('new_block', msg => {
    var div = document.createElement('div');
    div.setAttribute('id','block'+msg.id);
    div.setAttribute('class','block'+(msg.id%2));
    var blockid = document.createElement('div');
    blockid.setAttribute('class', 'block-id');
    blockid.textContent = msg.id+" :";
    div.appendChild(blockid);
    var blockhash = document.createElement('div');
    blockhash.setAttribute('class', 'block-hash');
    blockhash.textContent = msg.hash;
    var link = document.createElement('a');
    link.setAttribute('href', "/block/"+msg.id);
    link.appendChild(blockhash);
    div.appendChild(link);
    $("#block-list").prepend(div);
    $("#block"+(msg.id-20)).remove();
    
    update_ttm(msg.time_to_mine);
  })
}

const createStatusSocket = (main) => {
  let channel = socket.channel(`status:0`, {})
  channel.join()
    .receive("ok", resp => { console.log("Joined successfully", resp) })
    .receive("error", resp => { console.log("Unable to join", resp) })

  channel.on('new_status', msg => {
   
    document.getElementById('miners').innerHTML = msg.miners
    document.getElementById('wallets').innerHTML = msg.wallets
    document.getElementById('nodes').innerHTML = msg.nodes
    document.getElementById('lastblock').innerHTML = msg.lastblock
    document.getElementById('chainlength').innerHTML = msg.chainlength
    document.getElementById('utxo').innerHTML = msg.utxo
    document.getElementById('difficulty').innerHTML = msg.difficulty
    document.getElementById('target').innerHTML = msg.target
    document.getElementById('coins').innerHTML = msg.total_coins
    document.getElementById('bounty').innerHTML = msg.bounty
    update_difficulty(msg.difficulty);
    update_utxo(msg.utxo);
    update_pt(msg.pool_size);
  })
}

const createTransactionSocket = (transaction) =>{
  let channel = socket.channel(`transaction:${transaction}`, {})
  channel.join()
    .receive("ok", resp => { console.log("Joined successfully", resp) })
    .receive("error", resp => { console.log("Unable to join", resp) })

  channel.on('transaction_status', msg => {
    console.log("id"+msg.id+"balance"+msg.balance)
    document.getElementById('transaction_status').innerHTML = msg.status
    if(msg.block_number!=0){
      document.getElementById('block_link').setAttribute('href','/block/'+msg.block_number)
      document.getElementById('block_hash').innerHTML = msg.block_hash
    }
  })
}

window.createStatusSocket = createStatusSocket;
window.createSocket = createSocket;
window.createBlockSocket = createBlockSocket;
window.createTransactionSocket = createTransactionSocket;