defmodule Crypt do
    def generate_bitcoin_address() do
        {pk, sk} = :crypto.generate_key(:ecdh, :secp256k1)
        pk = Base.encode16(pk)
        sk = Base.encode16(sk)
        address = generate_bitcoin_address(pk)
        {address, pk, sk}
    end

    def generate_bitcoin_address(public_key) do
        hash(public_key)    
    end

    def generate_key(private_key) do
        :crypto.generate_key(:ecdh, :secp256k1, private_key)
    end

    def hash256(input) do
        :crypto.hash(:sha256, input) |> Base.encode16 
    end

    def hash160(input) do
        :crypto.hash(:ripemd160, input) |> Base.encode16
    end

    def hash(input) do
        hash160(hash256(input)) |> Base.encode16
    end

    def verifyhash256(hash, input) do
        hash == hash256(input)
    end

    def verifyhash160(hash, input) do
        hash == hash160(input)
    end

    def verifyhash(hash, input) do
        hash == hash(input)
    end

    def sign_input(input, private_key) do
        {_,private_key} = Base.decode16(private_key)
        {_,input} = Base.decode16(input)
        :crypto.sign(:ecdsa, :sha256, input, [private_key, :secp256k1]) |> Base.encode16
    end 

    def verify_input_signature(input) do
        sign = input.signature
        {_,public_key} = Base.decode16(input.public_key)
        {_,sign} = Base.decode16(sign)
        :crypto.verify(:ecdsa, :sha256, public_key, sign, [public_key, :secp256k1])
    end
end