let mutez_to_natural (a: tez) : nat =  a / 1mutez

let natural_to_mutez (a: nat): tez = a * 1mutez  

let is_a_nat (i : int) : nat option = Michelson.is_nat i
