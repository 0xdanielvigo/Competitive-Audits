// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// //run this test --> sudo forge test --match-path test/AuditTest/GeneralTest/GeneralTestSignatureReplayAttack.t.sol -vvv --via-ir

// import {Test, console} from "../../../lib/forge-std/src/Test.sol"; 

// import {ChakraSettlementHandler} from "../../../solidity/handler/contracts/ChakraSettlementHandler.sol"; 

// import {BaseSettlementHandler} from "../../../solidity/handler/contracts/BaseSettlementHandler.sol"; 

// import {ChakraToken} from "../../../solidity/handler/contracts/ChakraToken.sol"; 

// import {ERC20CodecV1} from "../../../solidity/handler/contracts/ERC20CodecV1.sol"; 

// import {IERC20CodecV1} from "../../../solidity/handler/contracts/interfaces/IERC20CodecV1.sol"; 

// import {ChakraSettlement} from "../../../solidity/settlement/contracts/ChakraSettlement.sol";

// import {SettlementSignatureVerifier} from "../../../solidity/handler/contracts/SettlementSignatureVerifier.sol";

// import {ISettlementSignatureVerifier} from "../../../solidity/handler/contracts/interfaces/ISettlementSignatureVerifier.sol";

// import {ISettlement} from "../../../solidity/handler/contracts/interfaces/ISettlement.sol";

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import { PayloadType, CrossChainMsgStatus } from "../../../solidity/settlement/contracts/libraries/Message.sol";

// import {ERC20TransferPayload} from "../../../solidity/handler/contracts/libraries/ERC20Payload.sol";

// import {ERC20Method} from "../../../solidity/handler/contracts/libraries/ERC20Payload.sol";

// import {AddressCast} from "../../../solidity/handler/contracts/libraries/AddressCast.sol";

// import {Message} from "../../../solidity/settlement/contracts/libraries/Message.sol";

// import {MessageV1Codec} from "../../../solidity/settlement/contracts/libraries/MessageV1Codec.sol";

// contract GeneralTestSignatureReplayAttack is Test{

//     uint256 ethFork; 
//     uint256 arbFork;
//     uint256 baseFork; 

// //ARB
// ChakraSettlementHandler public chakraSettlementHandlerArb; 

// ChakraToken public chakraTokenArb;

// ERC20CodecV1 public codecArb; 

// ChakraSettlement public chakraSettlementArb; 

// SettlementSignatureVerifier public settlementSignatureVerifierArb; 

// //ETH
// ChakraSettlementHandler public chakraSettlementHandlerEth; 

// ChakraToken public chakraTokenEth;

// ERC20CodecV1 public codecEth; 

// ChakraSettlement public chakraSettlementEth1; 
// ChakraSettlement public chakraSettlementEth2; 

// SettlementSignatureVerifier public settlementSignatureVerifierEth; 

// address public bob = makeAddr("bob");
// address public tob = makeAddr("tob");

// ChakraToken chakraToken_arb; 
// ChakraToken chakraToken_eth; 

// address public owner; 
   
// function setUp() public {
// initializeOnArbitrum();
// initializeOnEthereum();
// }

// function initializeOnArbitrum() public {
// arbFork = vm.createFork("here i used my arb rpc fork url");
// vm.selectFork(arbFork);
// owner = address(this); 

// //settlementSignatureVerifier 
// settlementSignatureVerifierArb = new SettlementSignatureVerifier(); 
// //settlementSignatureVerifier initialized
// settlementSignatureVerifierArb.initialize(address(this), 1);

// //chakraToken
// chakraToken_arb = new ChakraToken(); 
// //chakraToken initialized
// chakraToken_arb.initialize(address(this), address(this), "ChakraToken", "CKT", 18);

// //codec
// codecArb = new ERC20CodecV1(); 
// //codec initialized
// codecArb.initialize(address(this));

// //chakraSettlement
// chakraSettlementArb = new ChakraSettlement();
// address[] memory managers = new address[](2); 
// managers[0] = bob; 
// managers[1] = tob; 
// chakraSettlementArb.initialize("Abitrum", 137, owner, managers, 1, address(settlementSignatureVerifierArb));

// //chakraSettlementHandler
// chakraSettlementHandlerArb = new ChakraSettlementHandler();
// chakraSettlementHandlerArb.initialize(owner, BaseSettlementHandler.SettlementMode.LockMint, "Arbitrum", address(chakraToken_arb), address(codecArb), address(settlementSignatureVerifierArb), address(chakraSettlementArb));

// //add validator in chakra token
// chakraToken_arb.add_operator(address(chakraSettlementHandlerArb));
// }

// function initializeOnEthereum() public {
// ethFork = vm.createFork("here i used my eth rpc fork");
// vm.selectFork(ethFork);
// owner = address(this); 

// //settlementSignatureVerifier 
// settlementSignatureVerifierEth = new SettlementSignatureVerifier(); 
// //settlementSignatureVerifier initialized
// settlementSignatureVerifierEth.initialize(address(this), 1);

// //chakraToken
// chakraToken_eth = new ChakraToken(); 
// //chakraToken initialized
// chakraToken_eth.initialize(address(this), address(this), "ChakraToken", "CKT", 18);

// //codec
// codecEth = new ERC20CodecV1(); 
// //codec initialized
// codecEth.initialize(address(this));

// //chakraSettlement
// chakraSettlementEth1 = new ChakraSettlement();
// address[] memory managers = new address[](2); 
// managers[0] = bob; 
// managers[1] = tob; 
// chakraSettlementEth1.initialize("Ethereum", 1, owner, managers, 1, address(settlementSignatureVerifierEth));

// chakraSettlementEth2 = new ChakraSettlement();
// address[] memory managers2 = new address[](2); 
// managers2[0] = bob; 
// managers2[1] = tob; 
// chakraSettlementEth2.initialize("Ethereum", 1, owner, managers, 1, address(settlementSignatureVerifierEth));

// //chakraSettlementHandler
// chakraSettlementHandlerEth = new ChakraSettlementHandler();
// chakraSettlementHandlerEth.initialize(owner, BaseSettlementHandler.SettlementMode.LockMint, "Ethereum", address(chakraToken_eth), address(codecEth), address(settlementSignatureVerifierEth), address(chakraSettlementEth1));

// //add validator in chakra token
// chakraToken_eth.add_operator(address(chakraSettlementHandlerEth));
// }

// function test_signatureReplayAttack() public {
// //Note: the required validators is setted to 1, all the contracts have been initializated and the operator (SettlementHandler) has been added to chakra token in the 'setUp' file.
// uint256 privateKeyValidator1 = 0x12D; 
// address validator1 = vm.addr(privateKeyValidator1);

// address UserAccount1 = makeAddr("UserAccount1");

// //Here owner Adds managers to both chains (arbitrum and ethereum)
// vm.selectFork(arbFork);
// vm.startPrank(owner);
// settlementSignatureVerifierArb.add_manager(bob);
// vm.selectFork(ethFork);
// settlementSignatureVerifierEth.add_manager(bob);
// vm.stopPrank(); 

// //Here owner Adds validators to both chains (arbitrum and ethereum)
// vm.startPrank(bob);
// vm.selectFork(arbFork);
// settlementSignatureVerifierArb.add_validator(validator1);
// vm.selectFork(ethFork);
// settlementSignatureVerifierEth.add_validator(validator1);
// vm.stopPrank();

// //Here owner adds valid arbitrum handler on Ethereum
// vm.selectFork(ethFork);
// vm.startPrank(owner); 
// chakraSettlementHandlerEth.add_handler("Arbitrum", uint160(address(chakraSettlementHandlerArb)));
// vm.stopPrank();

// vm.startPrank(UserAccount1);
// vm.selectFork(arbFork);

// //payload 
// //Here there is a anticipated calculation of the cross chain tx payload, that will be used later in this test.
// bytes memory payload;
// uint256 crosschain_counter_msg = 1; 
// uint256 nonce = 1; 
// uint256 cross_chain_msg_id = uint256(keccak256(abi.encodePacked(crosschain_counter_msg,address(chakraSettlementHandlerArb), UserAccount1,nonce)));

// ERC20TransferPayload memory _payload = ERC20TransferPayload(
// ERC20Method.Transfer, 
// AddressCast.to_uint256(UserAccount1), 
// uint160(UserAccount1),
// AddressCast.to_uint256(address(chakraToken_arb)), //from token 
// uint160(address(chakraToken_eth)), //to token
// 100e18
// );

// Message memory cross_chain_msg = Message(
// cross_chain_msg_id, 
// PayloadType.ERC20, 
// codecArb.encode_transfer(_payload)
// );

// payload = MessageV1Codec.encode(cross_chain_msg);

// //Give 100 chakra token to user on Arbitrum
// deal(address(chakraToken_arb), UserAccount1, 100e18); 
// //Approve the handler 
// IERC20(address(chakraToken_arb)).approve(address(chakraSettlementHandlerArb), 100e18);

// //The user calls the base handler to perform his cross chain tx and he locks 100 chakra tokens on base
// chakraSettlementHandlerArb.cross_chain_erc20_settlement("Ethereum", uint160(address(chakraSettlementHandlerEth)), uint160(address(chakraToken_eth)), uint160(UserAccount1), 100e18);
// vm.stopPrank();

// uint256 nonce_manager = 1; 
// uint8 sign_type = 0; 
// uint256 txId = uint256(keccak256(abi.encodePacked("Arbitrum", "Ethereum", UserAccount1,uint160(address(chakraSettlementHandlerArb)),uint160(address(chakraSettlementHandlerEth)), nonce_manager)));

// vm.startPrank(validator1);
// //The validator signs the message and accepts the transaction
// (uint8 v,bytes32 r, bytes32 s) = vm.sign(privateKeyValidator1, 0xa6d88280451cfbbce6cc5945366c75f4ba0e19754e98ab54f4a8e1f85ef0851d);//Here we can note a byte value, it is the message_hash and has been retrieved using the Foundry console with the command -vvv
// bytes memory signature = abi.encodePacked(r, s, v);

// vm.selectFork(ethFork);
// //The validator calls 'receive_cross_chain_msg' on the destination chain (Ethereum)
// chakraSettlementEth1.receive_cross_chain_msg(txId, "Arbitrum", uint160(UserAccount1), uint160(address(chakraSettlementHandlerArb)), address(chakraSettlementHandlerEth), PayloadType.ERC20, payload, sign_type, signature);

// //Now the user has correctly 100 chakra tokens on Ethereum
// assertEq(IERC20(chakraToken_eth).balanceOf(address(UserAccount1)), 100e18);

// vm.stopPrank(); 

// vm.startPrank(UserAccount1);
// //Now the malicious user call 'receive_cross_chain_msg' with the same data in another settlement contract on ethereum
// chakraSettlementEth1.receive_cross_chain_msg(txId, "Arbitrum", uint160(UserAccount1), uint160(address(chakraSettlementHandlerArb)), address(chakraSettlementHandlerEth), PayloadType.ERC20, payload, sign_type, signature);
// }


// }