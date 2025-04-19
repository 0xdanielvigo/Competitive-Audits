// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol"; 

import {EntityForging} from "../../contracts/EntityForging/EntityForging.sol"; 
import {IEntityForging} from "../../contracts/EntityForging/IEntityForging.sol"; 
import {TraitForgeNft} from "../../contracts/TraitForgeNft/TraitForgeNft.sol"; 
import {ITraitForgeNft} from "../../contracts/TraitForgeNft/ITraitForgeNft.sol"; 
import {Airdrop} from "../../contracts/Airdrop/Airdrop.sol"; 
import {IAirdrop} from "../../contracts/Airdrop/IAirdrop.sol"; 
import {EntropyGenerator} from "../../contracts/EntropyGenerator/EntropyGenerator.sol"; 
import {IEntropyGenerator} from "../../contracts/EntropyGenerator/IEntropyGenerator.sol";

contract TraitForgeNftTest is Test {
address public owner; 

TraitForgeNft public traitForgeNft; 

Airdrop public airdropContract; 

EntityForging public entityForging; 

EntropyGenerator public entropyGenerator; 

function setUp() public {
owner = address(this); 
traitForgeNft = new TraitForgeNft(); 
airdropContract = new Airdrop(); 
entityForging = new EntityForging(address(traitForgeNft)); 
entropyGenerator = new EntropyGenerator(address(traitForgeNft)); 
}

//invariant variables
function invariant_maxTokenPerGenerations() public view {
assertEq(traitForgeNft.maxTokensPerGen(), 10000); 
}

//whiteListedEndTime
function test_initialWhiteListedEndTimeIsCorrect() public view {
assertEq(traitForgeNft.whitelistEndTime(), block.timestamp + 24 hours); 
}

//setNukeFundContract
function test_setNukeFundContractNotTheOwner() public {
vm.startPrank(address(11223)); 
vm.expectRevert(); 
traitForgeNft.setNukeFundContract(payable(address(123)));
}

function test_setNukeFundContractWorks() public {
vm.startPrank(owner); 
traitForgeNft.setNukeFundContract(payable(address(123)));
assertEq(traitForgeNft.nukeFundAddress(), payable(address(123))); 
}

//setEntityForgingContract
function test_setEntityForgingContractNotTheOwner() public {
vm.startPrank(address(1213)); 
vm.expectRevert(); 
traitForgeNft.setEntityForgingContract(address(122));
}

function test_setEntityForgingContractWorks() public {
vm.startPrank(owner); 
traitForgeNft.setEntityForgingContract(address(123));
IEntityForging _entityForgingContract = traitForgeNft.entityForgingContract(); 
assertEq(address(_entityForgingContract),address(123)); 
}

//setEntropyGenerator
function test_setEntropyGenratorNotTheOwner() public {
vm.startPrank(address(3141)); 
vm.expectRevert(); 
traitForgeNft.setEntropyGenerator(address(123));
}

function test_setEntropyGenratorWorks() public {
vm.startPrank(owner); 
traitForgeNft.setEntropyGenerator(address(123));
IEntropyGenerator _entropyGenrator = traitForgeNft.entropyGenerator(); 
assertEq(address(_entropyGenrator), address(123)); 
}

//setAirdropContract 
function test_setAidropContractNotTheOwner() public {
vm.startPrank(address(123)); 
vm.expectRevert(); 
traitForgeNft.setAirdropContract(address(12133));
}

function test_setAidropContractWorks() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(12133));
IAirdrop _airdrop = traitForgeNft.airdropContract(); 
assertEq(address(_airdrop), address(12133)); 
}

//startAirdrop
function test_startAirdropNotTheOwner() public {
vm.startPrank(address(13)); 
vm.expectRevert(); 
traitForgeNft.startAirdrop(111);
}

//setStartPrice
function test_setStartPriceNotTheOwner() public {
vm.startPrank(address(1324)); 
vm.expectRevert(); 
traitForgeNft.setStartPrice(0.001 ether);
}

function test_setStartPriceWorks(uint256 number) public {
vm.startPrank(owner); 
number = bound(number, 0, type(uint256).max); 
traitForgeNft.setStartPrice(number);
assertEq(traitForgeNft.startPrice(), number); 
}

//setPriceIncrement
function test_setPriceIncrementNotTheOwner() public {
vm.startPrank(address(1324)); 
vm.expectRevert(); 
traitForgeNft.setPriceIncrement(0.001 ether);
}

function test_setPriceIncrementWorks(uint256 number) public {
vm.startPrank(owner); 
number = bound(number, 0, type(uint256).max); 
traitForgeNft.setPriceIncrement(number);
assertEq(traitForgeNft.priceIncrement(), number); 
}

//setPriceIncrementByGen
function test_setPriceIncrementByGenNotTheOwner() public {
vm.startPrank(address(1324)); 
vm.expectRevert(); 
traitForgeNft.setPriceIncrementByGen(0.001 ether);
}

function test_setPriceIncrementByGenWorks(uint256 number) public {
vm.startPrank(owner); 
number = bound(number, 0, type(uint256).max); 
traitForgeNft.setPriceIncrementByGen(number);
assertEq(traitForgeNft.priceIncrementByGen(), number); 
}

//setMaxGeneration
function test_setMaxGenerationNotTheOwner() public {
vm.startPrank(address(1324)); 
vm.expectRevert(); 
traitForgeNft.setMaxGeneration(0.001 ether);
}

function test_setMaxGenertionWorks(uint256 number) public {
vm.startPrank(owner); 
number = bound(number, 1, type(uint256).max); 
traitForgeNft.setMaxGeneration(number);
assertEq(traitForgeNft.maxGeneration(), number); 
}

//setRootHash
function test_setRootHashNotTheOwner() public {
vm.startPrank(address(133)); 
vm.expectRevert();
traitForgeNft.setRootHash(keccak256(abi.encode("Hi")));
}

//setRootHash
function test_setRootHashWorks() public {
vm.startPrank(owner); 
bytes32 leave1 = keccak256(abi.encode("Hi"));
bytes32 leave2 = keccak256(abi.encode("Mom")); 
bytes32 leave3 = keccak256(abi.encode("How")); 
bytes32 leave4 = keccak256(abi.encode("Are you?"));  

bytes32 node1 = keccak256(abi.encode(leave1, leave2));
bytes32 node2 = keccak256(abi.encode(leave3, leave4));

bytes32 rootHash = keccak256(abi.encode(node1, node2));
traitForgeNft.setRootHash(rootHash);
assertEq(traitForgeNft.rootHash(), keccak256(abi.encode(node1, node2))); 
}

//setWhiteListEndTime
function test_setWhiteListEndTimeNotTheOwner() public {
vm.startPrank(address(1211)); 
vm.expectRevert(); 
traitForgeNft.setWhitelistEndTime(block.timestamp + 1 hours);
}

//setWhiteListEndTime
function test_setWhiteListEndTimeWorks() public {
vm.startPrank(owner); 
traitForgeNft.setWhitelistEndTime(1 hours);
assertEq(traitForgeNft.whitelistEndTime(), 1 hours); 
}

//mintToken
function test_mintTokenWorks() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 1 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 
traitForgeNft.mintToken{value: 0.005 ether}(proof);
}

function test_mintToken_mintPriceIsCorrect() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 10000 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 

uint256 mintPrice = 0.005 ether; 
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintToken{value: mintPrice}(proof);
mintPrice += 0.0000245 ether; 
assertEq(traitForgeNft.tokenCreationTimestamps(i + 1), block.timestamp); 
assertEq(traitForgeNft.tokenGenerations(i + 1), 1); 
assertEq(traitForgeNft.generationMintCounts(traitForgeNft.currentGeneration()), i + 1); 
assertEq(traitForgeNft.initialOwners(i + 1), user1); 
}

assertEq(traitForgeNft.totalSupply(), 10000); 

}


function test_mintToken_ExcessPaymentIsWellRefunded(uint256 value) public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 100 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 

uint256 initialMintPrice = traitForgeNft.startPrice(); 
value = bound(value, initialMintPrice, user1.balance); 
uint256 balanceBefore = user1.balance; 
uint256 mintPrice = traitForgeNft.startPrice(); 
traitForgeNft.mintToken{value: value}(proof);
uint256 balanceAfter = user1.balance; 
assertEq(balanceAfter, balanceBefore - mintPrice); 
}


function test_mintToken_fundsAreWellDistrubuted() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
address nukeFundAddress = address(142735484); 
traitForgeNft.setNukeFundContract(payable(nukeFundAddress));
airdropContract.transferOwnership(address(traitForgeNft));
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 1000 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 

uint256 initialMintPrice = traitForgeNft.startPrice(); 
uint256 totalSpentByUser; 
for(uint256 i = 0; i < 1000; i++){
traitForgeNft.mintToken{value: initialMintPrice}(proof);
totalSpentByUser += initialMintPrice; 
initialMintPrice += traitForgeNft.priceIncrement(); 
}

uint256 nukeFundAddressBalance = nukeFundAddress.balance; 
assertEq(nukeFundAddressBalance, totalSpentByUser); 
}

//mintWithBudget
function test_mintWithBudgetHighBudget() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
address nukeFundAddress = address(142735484); 
traitForgeNft.setNukeFundContract(payable(nukeFundAddress));
airdropContract.transferOwnership(address(traitForgeNft));
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 10000 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 

uint256 valueToPay = traitForgeNft.startPrice(); 
for(uint256 i = 0; i < 10000; i++){
valueToPay += traitForgeNft.priceIncrement(); 
}
for(uint256 i = 0; i < 12000; i++){
traitForgeNft.mintWithBudget{value: valueToPay}(proof);
}

assertEq(traitForgeNft.balanceOf(address(user1)), 10000); 
}



//VULNERABILITIES
//@audit-medium, as soon as 10000 nft get minted, this function will be not more  utilizable to mint nfts
// since 'tokenIds' will be higher than 'maxTokensPerGen' 
function test_vulnerability_mintWithBudget_DoesNotWotkAboveGen2() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
address nukeFundAddress = address(142735484); 
traitForgeNft.setNukeFundContract(payable(nukeFundAddress));
airdropContract.transferOwnership(address(traitForgeNft));
entropyGenerator.writeEntropyBatch1();
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 10000 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 

//Here the user mint 10.000 nfts (in the first gen) and he has effectively 10.000 nfts
uint256 initialMintPrice = traitForgeNft.startPrice(); 
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintWithBudget{value: initialMintPrice}(proof);
initialMintPrice += traitForgeNft.priceIncrement(); 
}
assertEq(traitForgeNft.balanceOf(address(user1)), 10000); 

//Here the user mints others 100 nfts (in the second gen) but he has again only 10.000 nfts and not 10.100 nfts
uint256 initialMintPrice2 = traitForgeNft.startPrice(); 
for(uint256 i = 0; i < 100; i++){
traitForgeNft.mintWithBudget{value: initialMintPrice2}(proof);
initialMintPrice += traitForgeNft.priceIncrement(); 
}

assertEq(traitForgeNft.balanceOf(address(user1)), 10000); 
}

//@audit-medium, it is not possible to mint new nfts (using mintToken and mintWithBudget) from the second generation 
//because 'TraitForgeNft' calls the 'initializeAlpha' function in the entropy contract but since it is not the owner, the call will fail
function test_vulnerability_mintToken_cantMintMoreGenerations() public {
vm.startPrank(owner); 
//Here the owner sets the contracts, transfer ownerships and write batch.
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
//According with the sponsor, 'TraitForgeNft' is the owner of 'Airdrop'
airdropContract.transferOwnership(address(traitForgeNft));
entropyGenerator.writeEntropyBatch1();
vm.stopPrank(); 

address user1 = address(123); 
//Assigning 10000 ether to user1
deal(user1, 10000 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 

//Here the user 1 mints the first 10.000 NFT's
uint256 price = traitForgeNft.startPrice(); 
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintToken{value: price}(proof);
price += traitForgeNft.priceIncrement() * traitForgeNft.getGeneration(); 
}
assertEq(traitForgeNft.balanceOf(user1), 10000); 

//When he tries to mint new NFT's, the function revert since TraiForgeNft is not the owner of EntropyGenerator
uint256 price2 = traitForgeNft.calculateMintPrice();
for(uint256 i = 0; i < 10000; i++){
vm.expectRevert(); 
traitForgeNft.mintToken{value: price2}(proof);
price2 = traitForgeNft.calculateMintPrice(); 
}
assertEq(traitForgeNft.balanceOf(user1), 10000);
}

//@audit-medium, there should be a maximum generation number, but instead, nfts can get minted to infinity
function test_vulnerability_NumberOfGenerationsIsInfinite() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
entropyGenerator.transferOwnership(address(traitForgeNft));
entropyGenerator.writeEntropyBatch1();
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 100000 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 

//generation 1
uint256 price = traitForgeNft.startPrice(); 
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintToken{value: price}(proof);
price += traitForgeNft.priceIncrement() * traitForgeNft.getGeneration(); 
}
assertEq(traitForgeNft.balanceOf(user1), 10000); 
//generation 2
uint256 price2 = traitForgeNft.calculateMintPrice();
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintToken{value: price2}(proof);
price2 = traitForgeNft.calculateMintPrice(); 
}
assertEq(traitForgeNft.balanceOf(user1), 20000);
//generation 3
uint256 price3 = traitForgeNft.calculateMintPrice();
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintToken{value: price3}(proof);
price3 = traitForgeNft.calculateMintPrice(); 
}
assertEq(traitForgeNft.balanceOf(user1), 30000);
//generation 4
uint256 price4 = traitForgeNft.calculateMintPrice();
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintToken{value: price4}(proof);
price4 = traitForgeNft.calculateMintPrice(); 
}
assertEq(traitForgeNft.balanceOf(user1), 40000);
//generation 5
uint256 price5 = traitForgeNft.calculateMintPrice();
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintToken{value: price5}(proof);
price5 = traitForgeNft.calculateMintPrice(); 
}
assertEq(traitForgeNft.balanceOf(user1), 50000);
//generation 6
uint256 price6 = traitForgeNft.calculateMintPrice();
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintToken{value: price6}(proof);
price6 = traitForgeNft.calculateMintPrice(); 
}
assertEq(traitForgeNft.balanceOf(user1), 60000);
//generation 7
uint256 price7 = traitForgeNft.calculateMintPrice();
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintToken{value: price7}(proof);
price7 = traitForgeNft.calculateMintPrice(); 
}
assertEq(traitForgeNft.balanceOf(user1), 70000);
//generation 8
uint256 price8 = traitForgeNft.calculateMintPrice();
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintToken{value: price8}(proof);
price8 = traitForgeNft.calculateMintPrice(); 
}
assertEq(traitForgeNft.balanceOf(user1), 80000);
//generation 9
uint256 price9 = traitForgeNft.calculateMintPrice();
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintToken{value: price9}(proof);
price9 = traitForgeNft.calculateMintPrice(); 
}
assertEq(traitForgeNft.balanceOf(user1), 90000);
//generation 10
uint256 price10 = traitForgeNft.calculateMintPrice();
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintToken{value: price10}(proof);
price10 = traitForgeNft.calculateMintPrice(); 
}
assertEq(traitForgeNft.balanceOf(user1), 100000);
//generation 11, this get also minted
uint256 price11 = traitForgeNft.calculateMintPrice();
for(uint256 i = 0; i < 10000; i++){
traitForgeNft.mintToken{value: price11}(proof);
price11 = traitForgeNft.calculateMintPrice(); 
}
assertEq(traitForgeNft.balanceOf(user1), 110000);
}

//@audit-high, due to a randomness problem, people can see what will be the next entropyValue for the next nft to be minted, 
//in this way people can frontrun others people and have an advantage by minting only the nfts with high entropy values or the specials nfts.
//In detail, user are able to see: 
// 1) The entropy value of the the nft to mint, more that is higher, more eth they will get by nuking it
// 2) If the next nft to mint is a forger
// 3) If the next nft to mint is a merger, and especially if the nft has the minimum forge potential required to merge the nft. 
//An user can see what will be the next entropy value for the the next nft simply by calling the 'getEntropy' function in entropyGenerator
//The user has to pass two arguments to this function, 'slotIndex' and 'numberIndex', these two variables are presents in traitForgeNft and they're private, but those can be seen anyway by calling their storage position slot. 
function test_vulnerability_PeopleCanOnlyMintNftsWithHighEntropyValues(uint256 entropyValue, uint256 highValue) public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
entropyGenerator.transferOwnership(address(traitForgeNft));
entropyGenerator.writeEntropyBatch1();
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 10 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi"));

bool isForger = (entropyValue % 3) == 0;

if(entropyValue >= highValue && isForger) {
console.log("This nft has good stats and it is a forger, i'll mint it"); 
traitForgeNft.mintToken{value: 0.005 ether}(proof);
} else {
console.log("This nft has bad stats, i won't mint it"); 
}
}
}

