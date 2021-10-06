import { TezosToolkit, MichelsonMap } from "@taquito/taquito";
import { InMemorySigner } from "@taquito/signer";
import { validateContractAddress } from "@taquito/utils";
import contractCode from "./contract.json";

let Tezos: TezosToolkit;
let contractAddress = "";
const alice = {
  sk: "edsk3QoqBuvdamxouPhin7swCvkQNgq4jP5KZPbwWNnwdZpSpJiEbq",
  pk: "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb"
};
const bob = {
  sk: "edsk3RFfvaFaxbHx8BMtEW1rKQcPtDML3LXjNqMNLCzC3wLC1bWbAt",
  pk: "tz1aSkwEot3L2kmUvcoxzjMomb9mvBNuzFK6"
};

describe("Setting up", () => {
  Tezos = new TezosToolkit("http://localhost:20000");
  const signer = new InMemorySigner(alice.sk);
  Tezos.setSignerProvider(signer);

  // originates the contract
  const ledger = new MichelsonMap();
  ledger.set({ 0: alice.pk, 1: 0 }, 1_000_000);
  ledger.set({ 0: alice.pk, 1: 1 }, 1_000_000);
  const tokenMetadata = new MichelsonMap();
  tokenMetadata.set(0, { token_id: 0, token_info: new MichelsonMap() });
  tokenMetadata.set(1, { token_id: 0, token_info: new MichelsonMap() });

  const initialStorage = {
    ledger,
    metadata: new MichelsonMap(),
    token_metadata: tokenMetadata,
    operators: new MichelsonMap(),
    whitelisted_minters: new MichelsonMap(),
    xtz_pool: 1_000_000,
    token_pool: 1_000_000,
    total_supply: 1_000_000,
    lqt_total: 1_000_000,
    lqt_token_id: 1,
    admin: alice.pk
  };

  test("Alice must have a balance", async () => {
    const balance = await Tezos.tz.getBalance(alice.pk);
    expect(balance.toNumber()).toBeGreaterThan(0);
  });
  test("Bob must have a balance", async () => {
    const balance = await Tezos.tz.getBalance(bob.pk);
    expect(balance.toNumber()).toBeGreaterThan(0);
  });
  test("Contract must be originated", async () => {
    const originationOp = await Tezos.contract.originate({
      code: contractCode,
      storage: initialStorage
    });
    const { contractAddress: address } = originationOp;
    contractAddress = address as string;
    expect(validateContractAddress(address)).toEqual(3);
  });
  test("Alice must be the admin of the contract", async () => {
    console.log(contractAddress);
    const contract = await Tezos.contract.at(contractAddress);
    const storage: any = await contract.storage();
    expect(storage.admin).toEqual(alice.pk);
  });
});
