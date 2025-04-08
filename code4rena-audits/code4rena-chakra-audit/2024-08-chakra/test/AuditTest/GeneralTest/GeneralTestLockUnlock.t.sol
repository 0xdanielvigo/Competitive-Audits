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

import { PayloadType} from "../../../solidity/settlement/contracts/libraries/Message.sol";

import {ERC20TransferPayload} from "../../../solidity/handler/contracts/libraries/ERC20Payload.sol";

import {ERC20Method} from "../../../solidity/handler/contracts/libraries/ERC20Payload.sol";

import {AddressCast} from "../../../solidity/handler/contracts/libraries/AddressCast.sol";

import {Message} from "../../../solidity/settlement/contracts/libraries/Message.sol";

import {MessageV1Codec} from "../../../solidity/settlement/contracts/libraries/MessageV1Codec.sol";

contract GeneralTestLockUnlock is Test{

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
chakraSettlementHandlerArb.initialize(owner, BaseSettlementHandler.SettlementMode.LockUnlock, "Arbitrum", address(chakraToken_arb), address(codecArb), address(settlementSignatureVerifierArb), address(chakraSettlementArb));

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
chakraSettlementHandlerEth.initialize(owner, BaseSettlementHandler.SettlementMode.LockUnlock, "Ethereum", address(chakraToken_eth), address(codecEth), address(settlementSignatureVerifierEth), address(chakraSettlementEth));

//add validator in chakra token
chakraToken_eth.add_operator(address(chakraSettlementHandlerEth));
}

//@audit medium, DOS attack, users could perform DOS attack to the ChakraNetwork
function test_sendCrossChainTx_Directly_ManyTimes() public {
vm.selectFork(arbFork);
address marco = address(123); 
vm.startPrank(marco); 
for(uint256 i = 0; i < 1000; i++){
chakraSettlementArb.send_cross_chain_msg("Ethereum", marco, uint160(address(chakraSettlementHandlerEth)), PayloadType.ERC20, "");
}
}

//@audit-high, if an user performs a cross chain tx to an handler with 'BurnUnlock' or 'LockUnlock' and there not enough tokens to unlock, user will lose his funds,
//since there is not a balance check. 
function test_FundsAreLosedIfThereAreNotEnoughTokensToUnlock() public {
//Note: the required validators is setted to 1.
uint256 privateKeyValidator1 = 0x12D; 
address validator1 = vm.addr(privateKeyValidator1);

address User = makeAddr("User");

//Add managers to both chains (arbitrum and ethereum)
vm.selectFork(arbFork);
vm.startPrank(owner);
settlementSignatureVerifierArb.add_manager(bob);
vm.selectFork(ethFork);
settlementSignatureVerifierEth.add_manager(bob);
vm.stopPrank(); 

//Add validators to both chains (arbitrum and ethereum)
vm.startPrank(bob);
settlementSignatureVerifierEth.add_validator(validator1);
vm.selectFork(arbFork);
settlementSignatureVerifierArb.add_validator(validator1);
vm.stopPrank();

//add valid handler on eth
vm.selectFork(ethFork);
vm.startPrank(owner); 
chakraSettlementHandlerEth.add_handler("Arbitrum", uint160(address(chakraSettlementHandlerArb)));
vm.stopPrank();

vm.startPrank(User);
vm.selectFork(arbFork);

//payload 
//Here there is a anticipated calculation of the cross chain tx payload, that will be used later in this test
bytes memory payload;
uint256 crosschain_counter_msg = 1; 
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

vm.selectFork(ethFork);
uint256 nonce_manager = 1; 
uint8 sign_type = 0; 
uint256 txId = uint256(keccak256(abi.encodePacked("Arbitrum", "Ethereum", uint160(User),uint160(address(chakraSettlementHandlerArb)),uint160(address(chakraSettlementHandlerEth)), nonce_manager)));

vm.startPrank(validator1);
//The validator signs the message and accepts the transaction
(uint8 v,bytes32 r, bytes32 s) = vm.sign(privateKeyValidator1, 0x6f7b326fce9079b25c82878b3628e1482f38f91995a184a641b444a24582d58f);//Here we can note a byte value, it is the message_hash and has been retrieved using the Foundry console with the command -vvv
bytes memory signature = abi.encodePacked(r, s, v);
vm.stopPrank(); 

vm.startPrank(User);
assertEq(IERC20(chakraToken_eth).balanceOf(User), 0); 
assertEq(IERC20(chakraToken_eth).balanceOf(address(chakraSettlementHandlerEth)), 0); //The eth handler has not the funds to unlock

//Here the user calls 'receive_cross_chain_msg' but this will revert since there are not tokens in the EthHandler contract
vm.expectRevert("Insufficient balance");
chakraSettlementEth.receive_cross_chain_msg(txId, "Arbitrum", uint160(User), uint160(address(chakraSettlementHandlerArb)),address(chakraSettlementHandlerEth), PayloadType.ERC20, payload, sign_type, signature);
}

}
