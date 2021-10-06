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
describe("Setting up", () => {
    Tezos = new taquito_1.TezosToolkit("http://localhost:20000");
    const signer = new signer_1.InMemorySigner(alice.sk);
    Tezos.setSignerProvider(signer);
    // originates the contract
    const ledger = new taquito_1.MichelsonMap();
    ledger.set({ 0: alice.pk, 1: 0 }, 1000000);
    ledger.set({ 0: alice.pk, 1: 1 }, 1000000);
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
        const { contractAddress: address } = originationOp;
        contractAddress = address;
        expect((0, utils_1.validateContractAddress)(address)).toEqual(3);
    });
    test("Alice must be the admin of the contract", async () => {
        console.log(contractAddress);
        const contract = await Tezos.contract.at(contractAddress);
        const storage = await contract.storage();
        expect(storage.admin).toEqual(alice.pk);
    });
});
