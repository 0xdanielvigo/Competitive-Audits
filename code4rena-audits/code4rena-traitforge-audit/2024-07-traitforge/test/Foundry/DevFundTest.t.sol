// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//run this test --> sudo forge test --match-path test/Foundry/DevFundTest.t.sol -vvv

import {Test, console} from "forge-std/Test.sol"; 

import {DevFund} from "../../contracts/DevFund/DevFund.sol"; 
import {IDevFund} from "../../contracts/DevFund/IDevFund.sol"; 

contract DevFundTest is Test {

DevFund public devFund; 

address public owner; 

function setUp() public {
owner = address(this); 
devFund = new DevFund(); 
vm.deal(owner,0); 
}

fallback() external payable{}

//receive
function test_triggerReceive_weightIs0(uint256 value) public {
address casualAddress = address(13131); 
vm.startPrank(casualAddress); 
vm.deal(casualAddress, 10000  ether); 
value = bound(value, 0, 1000 ether); 
(bool success, ) = payable(address(devFund)).call{value: value}(''); 
require(success, "Call failed"); 
address _owner = devFund.owner(); 
assertEq(_owner.balance, value); 
}

function test_triggerReceive_weightIsGt0(uint256 range, uint256 value) public {
vm.startPrank(owner); 
range = bound(range, 1, type(uint256).max); 
address dev = address(1213); 
devFund.addDev(dev, range);
uint256 totalDevWeight = devFund.totalDevWeight(); 

address casualAddress = address(13131); 
vm.startPrank(casualAddress); 
vm.deal(casualAddress, 10000  ether); 
value = bound(value, 0, 1000 ether); 
(bool success, ) = payable(address(devFund)).call{value: value}(''); 
require(success, "Call failed"); 
uint256 expectedRemainingBal = value - ((value / totalDevWeight) * totalDevWeight); 
address _owner = devFund.owner(); 
assertEq(_owner.balance, expectedRemainingBal); 
}

//AddDev
function test_addDevNotTheOwner()public {
address casualPLayer = address(123); 
vm.startPrank(casualPLayer); 
vm.expectRevert();
devFund.addDev(address(12), 1);
}

function test_addDevInvalidWeight() public {
vm.startPrank(owner); 
address casualDev = address(123);
vm.expectRevert(); 
devFund.addDev(casualDev, 0);
}

function test_addDevAlreadyRegistered() public {
vm.startPrank(owner); 
address casualDev = address(123);
devFund.addDev(casualDev, 1);
vm.expectRevert(); 
devFund.addDev(casualDev, 1);
}

function test_addDevWorks(uint256 range) public {
vm.startPrank(owner); 
range = bound(range, 1, type(uint256).max); 
address dev = address(1213); 
uint256 intialTotalDevWeight = devFund.totalDevWeight(); 
devFund.addDev(dev, range);

assertEq(devFund.totalDevWeight(), intialTotalDevWeight + range);
}


//updateDev
function test_updateDevWorks(uint256 range) public {
vm.startPrank(owner); 
address casualDev = address(123);
devFund.addDev(casualDev, 1);

range = bound(range, 1, type(uint256).max); 
devFund.updateDev(casualDev, range);
}

function test_updateDevInvalidWeight() public {
vm.startPrank(owner); 
address casualDev = address(123);
devFund.addDev(casualDev, 1);

vm.expectRevert();
devFund.updateDev(casualDev, 0);
}

function test_updateDevInvalidDev() public {
vm.startPrank(owner); 
address casualDev = address(123);
devFund.addDev(casualDev, 1);

address casualDev2 = address(1232);
vm.expectRevert();
devFund.updateDev(casualDev2, 1);
}

//removeDev
function test_removeDevWorks(uint256 range)public {
vm.startPrank(owner); 
address casualDev = address(123);
range = bound(range, 1, type(uint256).max); 
devFund.addDev(casualDev, range);

devFund.updateDev(casualDev, range);

devFund.removeDev(casualDev);
assertEq(devFund.totalDevWeight(), 0); 
}

function test_removeDevWorks2(uint256 range)public {
vm.startPrank(owner); 
address casualDev = address(123);
address casualDev2 = address(1231);
range = bound(range, 1, type(uint256).max / 2); 
devFund.addDev(casualDev, range);
devFund.addDev(casualDev2, range);

devFund.updateDev(casualDev, range);

devFund.removeDev(casualDev);
assertEq(devFund.totalDevWeight(), range); 
}

function test_removeDevIncorrectDev()public {
vm.startPrank(owner); 
address casualDev = address(123);
devFund.addDev(casualDev, 1);

devFund.updateDev(casualDev, 10);

address casualDev2 = address(1231);
vm.expectRevert();
devFund.removeDev(casualDev2);
}


//claim
function test_claimWorks(uint256 range) public {
vm.startPrank(owner); 
address casualDev = address(123);
devFund.addDev(casualDev, 1);

range = bound(range, 1, type(uint256).max); 
devFund.updateDev(casualDev, range);
vm.stopPrank(); 
vm.startPrank(casualDev); 
vm.deal(casualDev, 10  ether); 
(bool success, ) = payable(address(devFund)).call{value: 1 ether}(''); 
require(success, "Call failed"); 
uint256 pendingRewards = devFund.pendingRewards(address(casualDev));
devFund.claim();
assertEq(casualDev.balance, (10 ether - 1 ether) + pendingRewards); 
uint256 pendingRewards2 = devFund.pendingRewards(address(casualDev));
assertEq(pendingRewards2, 0); 
vm.stopPrank(); 
vm.startPrank(owner); 
devFund.updateDev(casualDev, range);
vm.stopPrank(); 
vm.startPrank(casualDev);  
uint256 pendingRewards3 = devFund.pendingRewards(address(casualDev));
assertEq( pendingRewards3 , 0); 
}



}
