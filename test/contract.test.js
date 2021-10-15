"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const taquito_1 = require("@taquito/taquito");
const signer_1 = require("@taquito/signer");
const utils_1 = require("@taquito/utils");
const contract_json_1 = __importDefault(require("./contract.json"));
let Tezos;
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
const aliceNativeTokenInitialBalance = 1000000;
const aliceLqtTokenInitialBalance = 1000000;
jest.setTimeout(30000);
describe("Setting up", () => {
    Tezos = new taquito_1.TezosToolkit("http://localhost:20000");
    const signer = new signer_1.InMemorySigner(alice.sk);
    Tezos.setSignerProvider(signer);
    // originates the contract
    const ledger = new taquito_1.MichelsonMap();
    ledger.set({ 0: alice.pk, 1: 0 }, aliceNativeTokenInitialBalance);
    ledger.set({ 0: alice.pk, 1: 1 }, aliceLqtTokenInitialBalance);
    const tokenMetadata = new taquito_1.MichelsonMap();
    tokenMetadata.set(0, { token_id: 0, token_info: new taquito_1.MichelsonMap() });
    tokenMetadata.set(1, { token_id: 0, token_info: new taquito_1.MichelsonMap() });
    const initialStorage = {
        ledger,
        metadata: new taquito_1.MichelsonMap(),
        token_metadata: tokenMetadata,
        operators: new taquito_1.MichelsonMap(),
        whitelisted_minters: new taquito_1.MichelsonMap(),
        xtz_pool: 1000000,
        token_pool: 1000000,
        total_supply: 1000000,
        lqt_total: 1000000,
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
            code: contract_json_1.default,
            storage: initialStorage
        });
        await originationOp.confirmation();
        const { contractAddress: address } = originationOp;
        contractAddress = address;
        expect((0, utils_1.validateContractAddress)(address)).toEqual(3);
    });
    test("Alice must be the admin of the contract", async () => {
        const contract = await Tezos.contract.at(contractAddress);
        const storage = await contract.storage();
        expect(storage.admin).toEqual(alice.pk);
    });
});
describe("Update operators", () => {
    test("Should set the contract as an operator for Alice", async () => {
        const contract = await Tezos.contract.at(contractAddress);
        const storage = await contract.storage();
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
        const storage = await contract.storage();
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
        expect(contract.methods
            .transfer([
            {
                from_: alice.pk,
                txs: [
                    { to_: bob.pk, token_id: 0, amount: aliceBalance.toNumber() + 1 }
                ]
            }
        ])
            .send()).rejects.toMatchObject({ message: "FA2_INSUFFICIENT_BALANCE" });
    });
    test("Should prevent transfer of unknown token id", async () => {
        const contract = await Tezos.contract.at(contractAddress);
        expect(contract.methods
            .transfer([
            {
                from_: alice.pk,
                txs: [{ to_: bob.pk, token_id: 2, amount: 10 }]
            }
        ])
            .send()).rejects.toMatchObject({ message: "FA2_TOKEN_UNDEFINED" });
    });
    test("Should prevent Alice from transferring Bob's tokens", async () => {
        const contract = await Tezos.contract.at(contractAddress);
        expect(contract.methods
            .transfer([
            {
                from_: bob.pk,
                txs: [{ to_: alice.pk, token_id: 0, amount: 10 }]
            }
        ])
            .send()).rejects.toMatchObject({ message: "FA2_NOT_OPERATOR" });
    });
    test("Should let Alice transfer tokens to Bob", async () => {
        const contract = await Tezos.contract.at(contractAddress);
        const storage = await contract.storage();
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
        expect(aliceNewBalance.toNumber()).toEqual(aliceBalance.toNumber() - amountToTransfer);
        const bobNewBalance = await storage.ledger.get({
            0: bob.pk,
            1: nativeTokenId
        });
        expect(bobNewBalance.toNumber()).toEqual(amountToTransfer);
    });
});
describe("Minting of tokens", () => {
    const tokensToMint = 1000000;
    test("Minting fails", async () => {
        const contract = await Tezos.contract.at(contractAddress);
        // this fails as Alice's address is not set as a minter
        expect(contract.methods.mint(alice.pk, 1000000, 0).send()).rejects.toMatchObject({ message: "UNAUTHORIZED_MINTER" });
        // sets Alice's address as a minter
        const storage = await contract.storage();
        const whitelistedAlice = await storage.whitelisted_minters.get(alice.pk);
        expect(whitelistedAlice).toBeUndefined();
        const newMinterOp = await contract.methods
            .update_whitelisted_minters(alice.pk)
            .send();
        await newMinterOp.confirmation();
        expect(newMinterOp.hash).toBeTruthy();
        expect(newMinterOp.status).toEqual("applied");
        // token minting with unknown token id
        expect(contract.methods.mint(alice.pk, tokensToMint, 2).send()).rejects.toMatchObject({ message: "FA2_TOKEN_UNDEFINED" });
    });
    test("Should mint tokens for Alice", async () => {
        const contract = await Tezos.contract.at(contractAddress);
        // sets Alice's address as a minter
        const storage = await contract.storage();
        const initialTokenTotalSupply = storage.total_supply.toNumber();
        const aliceInitialBalance = await storage.ledger.get({ 0: alice.pk, 1: 0 });
        const mintingOp = await contract.methods
            .mint(alice.pk, tokensToMint, 0)
            .send();
        await mintingOp.confirmation();
        expect(mintingOp.hash).toBeTruthy();
        expect(mintingOp.status).toEqual("applied");
        // checks that total supply has been incremented accordingly
        const newStorage = await contract.storage();
        const newTokenTotalSupply = newStorage.total_supply.toNumber();
        expect(newTokenTotalSupply).toEqual(initialTokenTotalSupply + tokensToMint);
        // checks that Alice's account has been incremented accordingly
        const aliceNewBalance = await newStorage.ledger.get({ 0: alice.pk, 1: 0 });
        expect(aliceNewBalance.toNumber()).toEqual(aliceInitialBalance.toNumber() + tokensToMint);
    });
});
