// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Test, console} from "forge-std/Test.sol"; 

import {MergeTgt} from "../../contracts/MergeTgt.sol"; 
import {Titn} from "../../contracts/Titn.sol"; 

import {Tgt} from "../../contracts/mocks/Tgt.sol"; 

import {IMerge} from "../../contracts/interfaces/IMerge.sol"; 

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";

import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

contract POC is Test {

MergeTgt public mergeTgt_arb; 

Titn public titn_arb; 
Titn public titn_base; 

Tgt public tgt_arb;

string public rpcurl_arb = "https://arb-mainnet.g.alchemy.com/v2/Z4iZqIYn02E4azjwQ6-utMqyFgY6ZSUX"; 
string public rpcurl_base = "https://base-mainnet.g.alchemy.com/v2/Z4iZqIYn02E4azjwQ6-utMqyFgY6ZSUX"; 

uint256 baseFork;
uint256 arbFork; 

address lzEndpoint_arb = 0x1a44076050125825900e736c501f859c50fE728c; 
address lzEndpoint_base = 0x1a44076050125825900e736c501f859c50fE728c; 

address public owner; 

function setUp() public { 
owner = address(this); 
baseFork = vm.createFork(rpcurl_base); 
arbFork = vm.createFork(rpcurl_arb); 

//Creating titn on base and minting 1 bilion tokens. 
vm.selectFork(baseFork);
titn_base = new Titn("baseTitn", "baseTitn", lzEndpoint_base, owner, 1_000_000_000 * 1e18); 

//Creating titn, mergeTgt and tgt on arbitrum and configuring data.
vm.selectFork(arbFork); 
titn_arb = new Titn("arbTitn", "arbTitn", lzEndpoint_arb, owner, 0); 
tgt_arb = new Tgt("Tgt", "TGT", owner, 1_000_000_000 * 1e18);
mergeTgt_arb = new MergeTgt(address(tgt_arb), address(titn_arb), owner); 
titn_arb.setTransferAllowedContract(address(mergeTgt_arb)); 
mergeTgt_arb.setLaunchTime();
mergeTgt_arb.setLockedStatus(IMerge.LockedStatus.OneWay);

//Simulating a bridge from base to arbitrum.
vm.selectFork(baseFork);
deal(address(titn_base), owner, (1_000_000_000 * 1e18) - (173_700_000 * 1e18)); 

vm.selectFork(arbFork); 
deal(address(titn_arb), owner, 173_700_000 * 1e18); 

//Depositing owner titn tokens into mergeTgt.
IERC20(titn_arb).approve(address(mergeTgt_arb), (173_700_000 * 1e18)); 
mergeTgt_arb.deposit(titn_arb, (173_700_000 * 1e18));

//setPeers
vm.selectFork(baseFork);
titn_base.setPeer(uint32(2), keccak256(abi.encode(address(titn_arb)))); 

vm.selectFork(arbFork);
titn_arb.setPeer(uint32(1), keccak256(abi.encode(address(titn_base)))); 
}


//In this case, an user deposited some tgt tokens, but was unable to claim his claimable titn tokens because there weren't enough funds in the contract.
// High
function test_thereIsNotABuyLimitInTheMergeTgtContract() public {
vm.selectFork(arbFork); 

address user1 = makeAddr("user1"); 
deal(address(tgt_arb), user1, 600_000_000 * 1e18); 
vm.startPrank(user1); 

IERC20(tgt_arb).approve(address(mergeTgt_arb), 600_000_000 * 1e18);
tgt_arb.transferAndCall(address(mergeTgt_arb), 600_000_000 * 1e18, "");

uint256 claimableTitn = mergeTgt_arb.getClaimableTitnPerUser(user1); 

vm.expectRevert(); 
mergeTgt_arb.claimTitn(claimableTitn);
}

//In this case, an user deposited some tgt tokens at the last second, but he didn't get any claimable titn tokens.
// Medium 
function test_usersCouldGet0TitnTokensByDepositingTgtTokens() public {
vm.selectFork(arbFork); 

skip(360 days); 
address user1 = makeAddr("user1"); 
deal(address(tgt_arb), user1, 100_000_000 * 1e18); 
vm.startPrank(user1); 

IERC20(tgt_arb).approve(address(mergeTgt_arb), 100_000_000  * 1e18);
tgt_arb.transferAndCall(address(mergeTgt_arb), 100_000_000  * 1e18, "");

uint256 claimableTitn = mergeTgt_arb.getClaimableTitnPerUser(user1); 

vm.assertEq(claimableTitn, 0); 
}

//In this case, when more than 360 days are passed away, the total amount of claimable tokens is higher than the actual balance of titn tokens in 
//the mergeTtg address causing an underflow.
// High
function test_withdrawRemainingTitnCouldUnderflow() public {
vm.selectFork(arbFork); 

address user1 = makeAddr("user1"); 
deal(address(tgt_arb), user1, 600_000_000 * 1e18); 
vm.startPrank(user1); 

IERC20(tgt_arb).approve(address(mergeTgt_arb), 600_000_000 * 1e18);
tgt_arb.transferAndCall(address(mergeTgt_arb), 600_000_000 * 1e18, "");

uint256 claimableTitn = mergeTgt_arb.getClaimableTitnPerUser(user1); 

assertGt(claimableTitn, IERC20(titn_arb).balanceOf(address(mergeTgt_arb))); 

//let's skip >= 360 days in order to call `withdrawRemainingTitn`. 
skip(380 days); 

vm.expectRevert(); 
mergeTgt_arb.withdrawRemainingTitn();
}


//In this case, an user got some titn tokens by the owner on base, but then another user sent them tokens from arbitrum (bridging them), 
//setting the variable isBridgedTokenHolder[user1] = true. 
//In this way, user1 can't transfer the non bridged token that he got by the owner. 
//For this vulnerability, consider mapping isBridgedTokenHolder[user1] based on the amount of bridged tokens. 
// Medium / High
function test_maliciousUserCouldNotAllowToTransferNonBridgedTokensOfOthersUsersOnBase() public {
vm.selectFork(baseFork); 

//Owner transfers some titn tokens to user 1, on base
vm.startPrank(owner); 
address user1 = makeAddr("user1"); 
IERC20(titn_base).transfer(user1, 10_000_000 * 1e18); 
assertEq(IERC20(titn_base).balanceOf(user1), 10_000_000 * 1e18); 
vm.stopPrank(); 

//User 1 is able to transfer tokens to others users
vm.startPrank(user1); 
address user2 = makeAddr("user2"); 
IERC20(titn_base).transfer(user2, 1_000_000 * 1e18); 
assertEq(IERC20(titn_base).balanceOf(user2), 1_000_000 * 1e18); 
vm.stopPrank(); 


//Now let's simulate a bridge from one arbitrum user to user 1 on base
vm.startPrank(lzEndpoint_base);

assertEq(titn_base.isBridgedTokenHolder(user1), false); 

Origin memory origin = Origin({
srcEid: 2, 
sender: keccak256(abi.encode(address(titn_arb))), 
nonce: 1
});
       
bytes32 guId = keccak256(abi.encode("transfer1")); 
bytes memory message = abi.encode(user1, 100 * 1e18); 
address executor = makeAddr("executor"); 
bytes memory extraData = "";

OFT(titn_base).lzReceive(origin, guId, message, executor, extraData);

assertEq(titn_base.isBridgedTokenHolder(user1), true); 
vm.stopPrank();


//Now, user 1 is not more able to send non bridged tokens (those token who he got by the owner).
vm.startPrank(user1); 
vm.expectRevert(Titn.BridgedTokensTransferLocked.selector);
IERC20(titn_base).transfer(user2, 1_000_000 * 1e18); 
vm.stopPrank(); 
}

//In this case, if the titn balance of the mergeTgt contract is equal to the total titn claimable amount, when an user 
//tries to call withdrawRemainingTitn(), he will receive his claimable tokens, but not also his proportional quote of the remaining titn tokens held in the contract, 
//breaking a protocol invariant. 
// High
function test_userCouldNotReceiveTITNLeftProportionalToTheirDeposit() public {
vm.selectFork(arbFork); 

//User obtains claimableTitnTokens.
address user1 = makeAddr("user1"); 
deal(address(tgt_arb), user1, 1_000_000 * 1e18); 
vm.startPrank(user1); 
IERC20(tgt_arb).approve(address(mergeTgt_arb), 1_000_000 * 1e18);
tgt_arb.transferAndCall(address(mergeTgt_arb), 1_000_000 * 1e18, "");

//let's imagine that the titn balance of the mergeTgt contract is equal to the total titn claimable amount. (A scenario that is possible).
uint256 user1ClaimableTitnTokens = mergeTgt_arb.getClaimableTitnPerUser(user1);
deal(address(titn_arb), address(mergeTgt_arb), user1ClaimableTitnTokens);

//Let's skip >= 360 days in order to call withdrawRemainingTitn()
skip(380 days); 

mergeTgt_arb.withdrawRemainingTitn();

//After claim, user has 0 claimable tokens.
assertEq(mergeTgt_arb.getClaimableTitnPerUser(user1), 0); 

//After claim, user has only receive his claimable titn tokens, and not also a proportional quote of the remaining titn tokens.
assertEq(IERC20(titn_arb).balanceOf(address(user1)), user1ClaimableTitnTokens);
}

}