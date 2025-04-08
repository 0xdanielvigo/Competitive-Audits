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

contract GeneralTestLockMint is Test{

    uint256 ethFork; 
    uint256 arbFork;
    uint256 baseFork; 

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

//BASE
ChakraSettlementHandler public chakraSettlementHandlerBase; 

ChakraToken public chakraTokenBase;

ERC20CodecV1 public codecBase; 

ChakraSettlement public chakraSettlementBase; 

SettlementSignatureVerifier public settlementSignatureVerifierBase; 

address public bob = makeAddr("bob");
address public tob = makeAddr("tob");

ChakraToken chakraToken_arb; 
ChakraToken chakraToken_eth; 
ChakraToken chakraToken_base; 

address public owner; 
   
function setUp() public {
initializeOnArbitrum();
initializeOnEthereum();
initializeOnBase();
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
chakraSettlementHandlerArb.initialize(owner, BaseSettlementHandler.SettlementMode.LockMint, "Arbitrum", address(chakraToken_arb), address(codecArb), address(settlementSignatureVerifierArb), address(chakraSettlementArb));

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
chakraSettlementHandlerEth.initialize(owner, BaseSettlementHandler.SettlementMode.LockMint, "Ethereum", address(chakraToken_eth), address(codecEth), address(settlementSignatureVerifierEth), address(chakraSettlementEth));

//add validator in chakra token
chakraToken_eth.add_operator(address(chakraSettlementHandlerEth));
}

function initializeOnBase() public {
baseFork = vm.createFork("use your own rpc url");
vm.selectFork(baseFork);
owner = address(this); 

//settlementSignatureVerifier 
settlementSignatureVerifierBase = new SettlementSignatureVerifier(); 
//settlementSignatureVerifier initialized
settlementSignatureVerifierBase.initialize(address(this), 1);

//chakraToken
chakraToken_base = new ChakraToken(); 
//chakraToken initialized
chakraToken_base.initialize(address(this), address(this), "ChakraToken", "CKT", 18);

//codec
codecBase = new ERC20CodecV1(); 
//codec initialized
codecBase.initialize(address(this));

//chakraSettlement
chakraSettlementBase = new ChakraSettlement();
address[] memory managers = new address[](2); 
managers[0] = bob; 
managers[1] = tob; 
chakraSettlementBase.initialize("Base", 1, owner, managers, 1, address(settlementSignatureVerifierBase));

//chakraSettlementHandler
chakraSettlementHandlerBase = new ChakraSettlementHandler();
chakraSettlementHandlerBase.initialize(owner, BaseSettlementHandler.SettlementMode.LockMint, "Base", address(chakraToken_base), address(codecBase), address(settlementSignatureVerifierBase), address(chakraSettlementBase));

//add validator in chakra token
chakraToken_base.add_operator(address(chakraSettlementHandlerBase));
}

//@audit-medium/high if settlement handler mode is setted to lockMint, the funds locked by the user will remain to be locked forever in the settlement handler contract and no burn is applied differently to the MintBurn mode
function test_inModeLockMintFundsCannotBeWithdrawUnlockedBurned() public {
//Note: the required validators is setted to 1, all the contracts have been initializated and the operator (SettlementHandler) has been added to chakra token in the 'setUp' file.
uint256 privateKeyValidator1 = 0x12D; 
address validator1 = vm.addr(privateKeyValidator1);

address UserAccount1 = makeAddr("UserAccount1");

//Here owner Adds managers to both chains (arbitrum and base)
vm.selectFork(arbFork);
vm.startPrank(owner);
settlementSignatureVerifierArb.add_manager(bob);
vm.selectFork(baseFork);
settlementSignatureVerifierBase.add_manager(bob);
vm.stopPrank(); 

//Here owner Adds validators to both chains (arbitrum and base)
vm.startPrank(bob);
vm.selectFork(arbFork);
settlementSignatureVerifierArb.add_validator(validator1);
vm.selectFork(baseFork);
settlementSignatureVerifierBase.add_validator(validator1);
vm.stopPrank();

//Here owner adds valid base handler on Arbitrum
vm.selectFork(arbFork);
vm.startPrank(owner); 
chakraSettlementHandlerArb.add_handler("Base", uint160(address(chakraSettlementHandlerBase)));
vm.stopPrank();

vm.startPrank(UserAccount1);
vm.selectFork(baseFork);

//payload 
//Here there is a anticipated calculation of the cross chain tx payload, that will be used later in this test.
bytes memory payload;
uint256 crosschain_counter_msg = 1; 
uint256 nonce = 1; 
uint256 cross_chain_msg_id = uint256(keccak256(abi.encodePacked(crosschain_counter_msg,address(chakraSettlementHandlerBase), UserAccount1,nonce)));

ERC20TransferPayload memory _payload = ERC20TransferPayload(
ERC20Method.Transfer, 
AddressCast.to_uint256(UserAccount1), 
uint160(UserAccount1),
AddressCast.to_uint256(address(chakraToken_base)), //from token 
uint160(address(chakraToken_arb)), //to token
100e18
);

Message memory cross_chain_msg = Message(
cross_chain_msg_id, 
PayloadType.ERC20, 
codecBase.encode_transfer(_payload)
);

payload = MessageV1Codec.encode(cross_chain_msg);

//Give 100 chakra token to user on base
deal(address(chakraToken_base), UserAccount1, 100e18); 
//Approve the handler 
IERC20(address(chakraToken_base)).approve(address(chakraSettlementHandlerBase), 100e18);

//The user calls the base handler to perform his cross chain tx and he locks 100 chakra tokens on base
chakraSettlementHandlerBase.cross_chain_erc20_settlement("Arbitrum", uint160(address(chakraSettlementHandlerArb)), uint160(address(chakraToken_arb)), uint160(UserAccount1), 100e18);
vm.stopPrank();

uint256 nonce_manager = 1; 
uint8 sign_type = 0; 
uint256 txId = uint256(keccak256(abi.encodePacked("Base", "Arbitrum", UserAccount1,uint160(address(chakraSettlementHandlerBase)),uint160(address(chakraSettlementHandlerArb)), nonce_manager)));

vm.startPrank(validator1);
//The validator signs the message and accepts the transaction
(uint8 v,bytes32 r, bytes32 s) = vm.sign(privateKeyValidator1, 0xee0e8fab5358d4376a87db6429a34102e02ff2a4188567c4d584f041dfe6d9ea);//Here we can note a byte value, it is the message_hash and has been retrieved using the Foundry console with the command -vvv
bytes memory signature = abi.encodePacked(r, s, v);

vm.selectFork(arbFork);
//The validator calls 'receive_cross_chain_msg' on the destination chain (arbitrum)
chakraSettlementArb.receive_cross_chain_msg(txId, "Base", uint160(UserAccount1), uint160(address(chakraSettlementHandlerBase)), address(chakraSettlementHandlerArb), PayloadType.ERC20, payload, sign_type, signature);

//Now the user has correctly 100 chakra tokens on arbitrum
assertEq(IERC20(chakraToken_arb).balanceOf(address(UserAccount1)), 100e18);

vm.selectFork(baseFork);
//The base settlement handler now holds the 100 chakra tokens locked by the user, but these tokens can't be unlocked or burned.
assertEq(IERC20(chakraToken_base).balanceOf(address(chakraSettlementHandlerBase)), 100e18);
}

function test_noInputValidationIn_cross_chain_erc20_settlement() public {
//Note: the required validators is setted to 1, the mode is set to LockMint, all the contracts have been initializated and the operator (SettlementHandler) has been added to chakra token in the 'setUp' file.
uint256 privateKeyValidator1 = 0x12D; 
address validator1 = vm.addr(privateKeyValidator1);

address UserAccount1 = makeAddr("UserAccount1");

//Here owner Adds managers to both chains (arbitrum and base)
vm.selectFork(arbFork);
vm.startPrank(owner);
settlementSignatureVerifierArb.add_manager(bob);
vm.selectFork(baseFork);
settlementSignatureVerifierBase.add_manager(bob);
vm.stopPrank(); 

//Here owner Adds validators to both chains (arbitrum and base)
vm.startPrank(bob);
vm.selectFork(arbFork);
settlementSignatureVerifierArb.add_validator(validator1);
vm.selectFork(baseFork);
settlementSignatureVerifierBase.add_validator(validator1);
vm.stopPrank();

//Here owner adds valid base handler on Arbitrum
vm.selectFork(arbFork);
vm.startPrank(owner); 
chakraSettlementHandlerArb.add_handler("Base", uint160(address(chakraSettlementHandlerBase)));
vm.stopPrank();

vm.startPrank(UserAccount1);
vm.selectFork(baseFork);

//Give 100 chakra token to user on base
deal(address(chakraToken_base), UserAccount1, 100e18); 
//Approve the handler 
IERC20(address(chakraToken_base)).approve(address(chakraSettlementHandlerBase), 100e18);

//Now the user send a cross chain transaction calling 'ChakraSettlementHandler::cross_chain_erc20_settlement'
//The user want to send a transaction to Arbitrum but by mistake, he does not pass "Arbitrum" in the field 'to_chain', but instead he pass "Arbatrom".
chakraSettlementHandlerBase.cross_chain_erc20_settlement("Arbatrom", uint160(address(chakraSettlementHandlerArb)), uint160(address(chakraToken_arb)), uint160(UserAccount1), 100e18);

//This call will not fail, but instead, it should since the 'to_chain' parameter is wrong and the validator could not approve the transaction. 
//This has an high impact since the user will lock his funds on chain A but he won't be able to mint others tokens in the chain B. 
//As result, the user will lose his locked funds, since there is not a logic to withdraw them.
}

function test_UsersCanIncreaseTheNonceOfTheOthersUsers() public {
//Note: the required validators is setted to 1, the mode is set to LockMint, all the contracts have been initializated and the operator (SettlementHandler) has been added to chakra token in the 'setUp' file.
address Mark = makeAddr("Mark");
address Giulia = makeAddr("Giulia");

vm.selectFork(arbFork);
vm.startPrank(Mark);

assertEq(chakraSettlementArb.nonce_manager(Giulia), 0); 

//Here mark increase the 'nonce_manager' on the settlement contract of Giulia just by calling 'ChakraSettlement::send_cross_chain_msg'. 
chakraSettlementArb.send_cross_chain_msg("Ethereum", Giulia, uint160(address(chakraSettlementHandlerEth)), PayloadType.ERC20, "");

assertEq(chakraSettlementArb.nonce_manager(Giulia), 1); 
}

function test_receive_cross_txsIsBadUpdated() public {
//Note: the required validators is setted to 1, all the contracts have been initializated and the operator (SettlementHandler) has been added to chakra token in the 'setUp' file.
uint256 privateKeyValidator1 = 0x12D; 
address validator1 = vm.addr(privateKeyValidator1);

address UserAccount1 = makeAddr("UserAccount1");

//Here owner Adds managers to both chains (arbitrum and base)
vm.selectFork(arbFork);
vm.startPrank(owner);
settlementSignatureVerifierArb.add_manager(bob);
vm.selectFork(baseFork);
settlementSignatureVerifierBase.add_manager(bob);
vm.stopPrank(); 

//Here owner Adds validators to both chains (arbitrum and base)
vm.startPrank(bob);
vm.selectFork(arbFork);
settlementSignatureVerifierArb.add_validator(validator1);
vm.selectFork(baseFork);
settlementSignatureVerifierBase.add_validator(validator1);
vm.stopPrank();

//Here owner adds valid base handler on Arbitrum
vm.selectFork(arbFork);
vm.startPrank(owner); 
chakraSettlementHandlerArb.add_handler("Base", uint160(address(chakraSettlementHandlerBase)));
vm.stopPrank();

vm.startPrank(UserAccount1);
vm.selectFork(baseFork);

//payload 
//Here there is a anticipated calculation of the cross chain tx payload, that will be used later in this test.
bytes memory payload;
uint256 crosschain_counter_msg = 1; 
uint256 nonce = 1; 
uint256 cross_chain_msg_id = uint256(keccak256(abi.encodePacked(crosschain_counter_msg,address(chakraSettlementHandlerBase), UserAccount1,nonce)));

ERC20TransferPayload memory _payload = ERC20TransferPayload(
ERC20Method.Transfer, 
AddressCast.to_uint256(UserAccount1), 
uint160(UserAccount1),
AddressCast.to_uint256(address(chakraToken_base)), //from token 
uint160(address(chakraToken_arb)), //to token
100e18
);

Message memory cross_chain_msg = Message(
cross_chain_msg_id, 
PayloadType.ERC20, 
codecBase.encode_transfer(_payload)
);

payload = MessageV1Codec.encode(cross_chain_msg);

//Give 100 chakra token to user on base
deal(address(chakraToken_base), UserAccount1, 100e18); 
//Approve the handler 
IERC20(address(chakraToken_base)).approve(address(chakraSettlementHandlerBase), 100e18);

//The user calls the base handler to perform his cross chain tx and he locks 100 chakra tokens on base
chakraSettlementHandlerBase.cross_chain_erc20_settlement("Arbitrum", uint160(address(chakraSettlementHandlerArb)), uint160(address(chakraToken_arb)), uint160(UserAccount1), 100e18);
vm.stopPrank();

uint256 nonce_manager = 1; 
uint8 sign_type = 0; 
uint256 txId = uint256(keccak256(abi.encodePacked("Base", "Arbitrum", UserAccount1,uint160(address(chakraSettlementHandlerBase)),uint160(address(chakraSettlementHandlerArb)), nonce_manager)));

vm.startPrank(validator1);
//The validator signs the message and accepts the transaction
(uint8 v,bytes32 r, bytes32 s) = vm.sign(privateKeyValidator1, 0xee0e8fab5358d4376a87db6429a34102e02ff2a4188567c4d584f041dfe6d9ea);//Here we can note a byte value, it is the message_hash and has been retrieved using the Foundry console with the command -vvv
bytes memory signature = abi.encodePacked(r, s, v);

vm.selectFork(arbFork);
//The validator calls 'receive_cross_chain_msg' on the destination chain (arbitrum)
chakraSettlementArb.receive_cross_chain_msg(txId, "Base", uint160(UserAccount1), uint160(address(chakraSettlementHandlerBase)), address(chakraSettlementHandlerArb), PayloadType.ERC20, payload, sign_type, signature);

(, , , , , address toHandler , ,) = chakraSettlementArb.receive_cross_txs(txId);
//The value 'to_handler' is not effectively the handler on the arbitrum chain, but it is the settlement contract
assertEq(toHandler, address(chakraSettlementArb));
}

}