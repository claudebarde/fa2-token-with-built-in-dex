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
const nativeTokenId = 0;
const lqtTokenId = 1;
const aliceNativeTokenInitialBalance = 1_000_000;
const aliceLqtTokenInitialBalance = 1_000_000;

jest.setTimeout(30000);

describe("Setting up", () => {
  Tezos = new TezosToolkit("http://localhost:20000");
  const signer = new InMemorySigner(alice.sk);
  Tezos.setSignerProvider(signer);

  // originates the contract
  const ledger = new MichelsonMap();
  ledger.set({ 0: alice.pk, 1: 0 }, aliceNativeTokenInitialBalance);
  ledger.set({ 0: alice.pk, 1: 1 }, aliceLqtTokenInitialBalance);
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
    jest.setTimeout(30000);

    const originationOp = await Tezos.contract.originate({
      code: contractCode,
      storage: initialStorage
    });
    await originationOp.confirmation();
    const { contractAddress: address } = originationOp;
    contractAddress = address as string;
    expect(validateContractAddress(address)).toEqual(3);
  });
  test("Alice must be the admin of the contract", async () => {
    const contract = await Tezos.contract.at(contractAddress);
    const storage: any = await contract.storage();
    expect(storage.admin).toEqual(alice.pk);
  });
});

describe("Update operators", () => {
  test("Should set the contract as an operator for Alice", async () => {
    const contract = await Tezos.contract.at(contractAddress);
    const storage: any = await contract.storage();
    // verifies initial state
    const aliceOperatorForToken0 = await storage.operators.get({
      0: alice.pk,
      1: contractAddress,
      2: nativeTokenId
    });
    expect(aliceOperatorForToken0).toBeUndefined();
    const aliceOperatorForToken1 = await storage.operators.get({
      0: alice.pk,
      1: contractAddress,
      2: lqtTokenId
    });
    expect(aliceOperatorForToken1).toBeUndefined();
    // updates operator
    const op = await contract.methods
      .update_operators([
        {
          add_operator: {
            owner: alice.pk,
            operator: contractAddress,
            token_id: nativeTokenId
          }
        },
        {
          add_operator: {
            owner: alice.pk,
            operator: contractAddress,
            token_id: lqtTokenId
          }
        }
      ])
      .send();
    await op.confirmation();
    // verifies new state
    const aliceNewOperatorForToken0 = await storage.operators.get({
      0: alice.pk,
      1: contractAddress,
      2: nativeTokenId
    });
    expect(aliceNewOperatorForToken0).toBeTruthy();
    expect(typeof aliceNewOperatorForToken0).toBe("symbol");
    const aliceNewOperatorForToken1 = await storage.operators.get({
      0: alice.pk,
      1: contractAddress,
      2: lqtTokenId
    });
    expect(aliceNewOperatorForToken1).toBeTruthy();
    expect(typeof aliceNewOperatorForToken1).toBe("symbol");
  });
});

describe("Transfers", () => {
  test("Should prevent Alice to transfer tokens she doesn't have", async () => {
    const contract = await Tezos.contract.at(contractAddress);
    const storage: any = await contract.storage();
    // verifies Alice's initial balance
    const aliceBalance = await storage.ledger.get({
      0: alice.pk,
      1: nativeTokenId
    });
    expect(aliceBalance.toNumber()).toEqual(aliceNativeTokenInitialBalance);
    const bobBalance = await storage.ledger.get({
      0: bob.pk,
      1: nativeTokenId
    });
    expect(bobBalance).toBeUndefined();
    // failed transfer
    expect(
      contract.methods
        .transfer([
          {
            from_: alice.pk,
            txs: [
              { to_: bob.pk, token_id: 0, amount: aliceBalance.toNumber() + 1 }
            ]
          }
        ])
        .send()
    ).rejects.toMatchObject({ message: "FA2_INSUFFICIENT_BALANCE" });
  });
  test("Should let Alice transfer tokens to Bob", async () => {
    const contract = await Tezos.contract.at(contractAddress);
    const storage: any = await contract.storage();
    const aliceBalance = await storage.ledger.get({
      0: alice.pk,
      1: nativeTokenId
    });
    expect(aliceBalance.toNumber()).toEqual(aliceNativeTokenInitialBalance);
    const bobBalance = await storage.ledger.get({
      0: bob.pk,
      1: nativeTokenId
    });
    expect(bobBalance).toBeUndefined();
    // transfer to Bob
    const amountToTransfer = aliceBalance.toNumber() / 10;
    const transferOp = await contract.methods
      .transfer([
        {
          from_: alice.pk,
          txs: [{ to_: bob.pk, token_id: 0, amount: amountToTransfer }]
        }
      ])
      .send();
    await transferOp.confirmation();
    const aliceNewBalance = await storage.ledger.get({
      0: alice.pk,
      1: nativeTokenId
    });
    expect(aliceNewBalance.toNumber()).toEqual(
      aliceBalance.toNumber() - amountToTransfer
    );
    const bobNewBalance = await storage.ledger.get({
      0: bob.pk,
      1: nativeTokenId
    });
    expect(bobNewBalance.toNumber()).toEqual(amountToTransfer);
  });
});
