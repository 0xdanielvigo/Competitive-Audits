# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 6 |
| [GAS-2](#GAS-2) | Using bools for storage incurs overhead | 2 |
| [GAS-3](#GAS-3) | For Operations that will not overflow, you could use unchecked | 38 |
| [GAS-4](#GAS-4) | Use Custom Errors instead of Revert Strings to save Gas | 5 |
| [GAS-5](#GAS-5) | Avoid contract existence checks by using low level calls | 3 |
| [GAS-6](#GAS-6) | State variables only set in the constructor should be declared `immutable` | 3 |
| [GAS-7](#GAS-7) | Functions guaranteed to revert when called by normal users can be marked `payable` | 6 |
| [GAS-8](#GAS-8) | Using `private` rather than `public` for constants, saves gas | 2 |
| [GAS-9](#GAS-9) | Superfluous event fields | 1 |
| [GAS-10](#GAS-10) | Use != 0 instead of > 0 for unsigned integer comparison | 3 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (6)*:
```solidity
File: ./contracts/MergeTgt.sol

82:         claimableTitnPerUser[from] += titnOut;

83:         totalTitnClaimable += titnOut;

103:         claimedTitnPerUser[msg.sender] += amount;

106:         totalTitnClaimed += amount;

142:         totalTitnClaimed += titnOut;

144:         claimedTitnPerUser[msg.sender] += titnOut;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="GAS-2"></a>[GAS-2] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (2)*:
```solidity
File: ./contracts/Titn.sol

9:     mapping(address => bool) public isBridgedTokenHolder;

10:     bool private isBridgedTokensTransferLocked;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="GAS-3"></a>[GAS-3] For Operations that will not overflow, you could use unchecked

*Instances (38)*:
```solidity
File: ./contracts/MergeTgt.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

5: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

6: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import {IERC677Receiver} from "./interfaces/IERC677Receiver.sol";

9: import {IMerge} from "./interfaces/IMerge.sol";

17:     uint256 public constant TGT_TO_EXCHANGE = 579_000_000 * 10 ** 18; // 57.9% of MAX_TGT

18:     uint256 public constant TITN_ARB = 173_700_000 * 10 ** 18; // 17.37% of MAX_TITN

26:     uint256 public initialTotalClaimable; // store the initial claimable TITN after 1 year

75:         if (block.timestamp - launchTime > 360 days) {

82:         claimableTitnPerUser[from] += titnOut;

83:         totalTitnClaimable += titnOut;

99:         if (block.timestamp - launchTime >= 360 days) {

103:         claimedTitnPerUser[msg.sender] += amount;

104:         claimableTitnPerUser[msg.sender] -= amount;

106:         totalTitnClaimed += amount;

107:         totalTitnClaimable -= amount;

117:         if (block.timestamp - launchTime < 360 days) {

135:         uint256 unclaimedTitn = remainingTitnAfter1Year - initialTotalClaimable;

136:         uint256 userProportionalShare = (claimableTitn * unclaimedTitn) / initialTotalClaimable;

138:         uint256 titnOut = claimableTitn + userProportionalShare;

141:         claimableTitnPerUser[msg.sender] = 0; // each user can only claim once

142:         totalTitnClaimed += titnOut;

144:         claimedTitnPerUser[msg.sender] += titnOut;

145:         totalTitnClaimable -= claimableTitn;

156:         uint256 timeSinceLaunch = (block.timestamp - launchTime);

158:             titnAmount = (tgtAmount * TITN_ARB) / TGT_TO_EXCHANGE;

160:             uint256 remainingtime = 360 days - timeSinceLaunch;

161:             titnAmount = (tgtAmount * TITN_ARB * remainingtime) / (TGT_TO_EXCHANGE * 270 days); //270 days = 9 months

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

5: import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";

77:             from != owner() && // Exclude owner from restrictions

78:             from != transferAllowedContract && // Allow transfers to the transferAllowedContract

79:             to != transferAllowedContract && // Allow transfers to the transferAllowedContract

80:             isBridgedTokensTransferLocked && // Check if bridged transfers are locked

83:             to != lzEndpoint // Allow transfers to LayerZero endpoint

99:         uint32 /*_srcEid*/

101:         if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="GAS-4"></a>[GAS-4] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (5)*:
```solidity
File: ./contracts/MergeTgt.sol

97:         require(amount <= claimableTitnPerUser[msg.sender], "Not enough claimable titn");

115:         require(launchTime > 0, "Launch time not set");

132:         require(claimableTitn > 0, "No claimable TITN");

154:         require(launchTime > 0, "Launch time not set");

173:         require(launchTime == 0, "Launch time already set");

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="GAS-5"></a>[GAS-5] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (3)*:
```solidity
File: ./contracts/MergeTgt.sol

89:         return tgt.balanceOf(address(this));

93:         return titn.balanceOf(address(this));

121:         uint256 currentRemainingTitn = titn.balanceOf(address(this));

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="GAS-6"></a>[GAS-6] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (3)*:
```solidity
File: ./contracts/MergeTgt.sol

40:         tgt = IERC20(_tgt);

41:         titn = IERC20(_titn);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

24:         lzEndpoint = _lzEndpoint;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="GAS-7"></a>[GAS-7] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (6)*:
```solidity
File: ./contracts/MergeTgt.sol

44:     function deposit(IERC20 token, uint256 amount) external onlyOwner {

59:     function withdraw(IERC20 token, uint256 amount) external onlyOwner {

167:     function setLockedStatus(LockedStatus newStatus) external onlyOwner {

172:     function setLaunchTime() external onlyOwner {

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

33:     function setTransferAllowedContract(address _transferAllowedContract) external onlyOwner {

43:     function setBridgedTokenTransferLocked(bool _isLocked) external onlyOwner {

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="GAS-8"></a>[GAS-8] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (2)*:
```solidity
File: ./contracts/MergeTgt.sol

17:     uint256 public constant TGT_TO_EXCHANGE = 579_000_000 * 10 ** 18; // 57.9% of MAX_TGT

18:     uint256 public constant TITN_ARB = 173_700_000 * 10 ** 18; // 17.37% of MAX_TITN

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="GAS-9"></a>[GAS-9] Superfluous event fields
`block.timestamp` and `block.number` are added to event information by default so adding them manually wastes gas

*Instances (1)*:
```solidity
File: ./contracts/MergeTgt.sol

33:     event LaunchTimeSet(uint256 timestamp);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="GAS-10"></a>[GAS-10] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (3)*:
```solidity
File: ./contracts/MergeTgt.sol

115:         require(launchTime > 0, "Launch time not set");

132:         require(claimableTitn > 0, "No claimable TITN");

154:         require(launchTime > 0, "Launch time not set");

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [NC-2](#NC-2) | `constant`s should be defined rather than using magic numbers | 8 |
| [NC-3](#NC-3) | Control structures do not follow the Solidity Style Guide | 3 |
| [NC-4](#NC-4) | Consider disabling `renounceOwnership()` | 1 |
| [NC-5](#NC-5) | Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function | 2 |
| [NC-6](#NC-6) | Event missing indexed field | 3 |
| [NC-7](#NC-7) | Events that mark critical parameter changes should contain both the old and the new value | 4 |
| [NC-8](#NC-8) | Function ordering does not follow the Solidity style guide | 1 |
| [NC-9](#NC-9) | Functions should not be longer than 50 lines | 19 |
| [NC-10](#NC-10) | Change int to int256 | 2 |
| [NC-11](#NC-11) | Change uint to uint256 | 1 |
| [NC-12](#NC-12) | Lack of checks in setters | 3 |
| [NC-13](#NC-13) | NatSpec is completely non-existent on functions that should have them | 9 |
| [NC-14](#NC-14) | Incomplete NatSpec: `@param` is missing on actually documented functions | 2 |
| [NC-15](#NC-15) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 2 |
| [NC-16](#NC-16) | Consider using named mappings | 3 |
| [NC-17](#NC-17) | Adding a `return` statement when the function defines a named return variable, is redundant | 1 |
| [NC-18](#NC-18) | Take advantage of Custom Error's return value property | 9 |
| [NC-19](#NC-19) | Use scientific notation (e.g. `1e18`) rather than exponentiation (e.g. `10**18`) | 2 |
| [NC-20](#NC-20) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-21](#NC-21) | Use Underscores for Number Literals (add an underscore every 3 digits) | 1 |
| [NC-22](#NC-22) | Internal and private variables and functions names should begin with an underscore | 2 |
| [NC-23](#NC-23) | Event is missing `indexed` fields | 8 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: ./contracts/Titn.sol

24:         lzEndpoint = _lzEndpoint;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-2"></a>[NC-2] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (8)*:
```solidity
File: ./contracts/MergeTgt.sol

75:         if (block.timestamp - launchTime > 360 days) {

99:         if (block.timestamp - launchTime >= 360 days) {

117:         if (block.timestamp - launchTime < 360 days) {

157:         if (timeSinceLaunch < 90 days) {

159:         } else if (timeSinceLaunch < 360 days) {

160:             uint256 remainingtime = 360 days - timeSinceLaunch;

161:             titnAmount = (tgtAmount * TITN_ARB * remainingtime) / (TGT_TO_EXCHANGE * 270 days); //270 days = 9 months

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

73:         uint256 arbitrumChainId = 42161;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-3"></a>[NC-3] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (3)*:
```solidity
File: ./contracts/Titn.sol

76:         if (

80:             isBridgedTokensTransferLocked && // Check if bridged transfers are locked

101:         if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-4"></a>[NC-4] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (1)*:
```solidity
File: ./contracts/MergeTgt.sol

11: contract MergeTgt is IMerge, Ownable, ReentrancyGuard {

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="NC-5"></a>[NC-5] Duplicated `require()`/`revert()` Checks Should Be Refactored To A Modifier Or Function

*Instances (2)*:
```solidity
File: ./contracts/MergeTgt.sol

115:         require(launchTime > 0, "Launch time not set");

154:         require(launchTime > 0, "Launch time not set");

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="NC-6"></a>[NC-6] Event missing indexed field
Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (3)*:
```solidity
File: ./contracts/MergeTgt.sol

33:     event LaunchTimeSet(uint256 timestamp);

34:     event LockedStatusUpdated(LockedStatus newStatus);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

42:     event BridgedTokenTransferLockUpdated(bool isLocked);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-7"></a>[NC-7] Events that mark critical parameter changes should contain both the old and the new value
This should especially be done if the new value is not required to be different from the old value

*Instances (4)*:
```solidity
File: ./contracts/MergeTgt.sol

167:     function setLockedStatus(LockedStatus newStatus) external onlyOwner {
             lockedStatus = newStatus;
             emit LockedStatusUpdated(newStatus);

172:     function setLaunchTime() external onlyOwner {
             require(launchTime == 0, "Launch time already set");
             launchTime = block.timestamp;
             emit LaunchTimeSet(block.timestamp);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

33:     function setTransferAllowedContract(address _transferAllowedContract) external onlyOwner {
            transferAllowedContract = _transferAllowedContract;
            emit TransferAllowedContractUpdated(_transferAllowedContract);

43:     function setBridgedTokenTransferLocked(bool _isLocked) external onlyOwner {
            isBridgedTokensTransferLocked = _isLocked;
            emit BridgedTokenTransferLockUpdated(_isLocked);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-8"></a>[NC-8] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (1)*:
```solidity
File: ./contracts/MergeTgt.sol

1: 
   Current order:
   external deposit
   external withdraw
   external onTokenTransfer
   external tgtBalance
   external titnBalance
   external claimTitn
   external withdrawRemainingTitn
   public quoteTitn
   external setLockedStatus
   external setLaunchTime
   external gettotalClaimedTitnPerUser
   external getClaimableTitnPerUser
   
   Suggested order:
   external deposit
   external withdraw
   external onTokenTransfer
   external tgtBalance
   external titnBalance
   external claimTitn
   external withdrawRemainingTitn
   external setLockedStatus
   external setLaunchTime
   external gettotalClaimedTitnPerUser
   external getClaimableTitnPerUser
   public quoteTitn

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="NC-9"></a>[NC-9] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (19)*:
```solidity
File: ./contracts/MergeTgt.sol

44:     function deposit(IERC20 token, uint256 amount) external onlyOwner {

59:     function withdraw(IERC20 token, uint256 amount) external onlyOwner {

65:     function onTokenTransfer(address from, uint256 amount, bytes calldata extraData) external nonReentrant {

88:     function tgtBalance() external view returns (uint256) {

92:     function titnBalance() external view returns (uint256) {

96:     function claimTitn(uint256 amount) external nonReentrant {

114:     function withdrawRemainingTitn() external nonReentrant {

153:     function quoteTitn(uint256 tgtAmount) public view returns (uint256 titnAmount) {

167:     function setLockedStatus(LockedStatus newStatus) external onlyOwner {

178:     function gettotalClaimedTitnPerUser(address user) external view returns (uint256) {

182:     function getClaimableTitnPerUser(address user) external view returns (uint256) {

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

33:     function setTransferAllowedContract(address _transferAllowedContract) external onlyOwner {

38:     function getTransferAllowedContract() external view returns (address) {

43:     function setBridgedTokenTransferLocked(bool _isLocked) external onlyOwner {

48:     function getBridgedTokenTransferLocked() external view returns (bool) {

56:     function transfer(address to, uint256 amount) public override returns (bool) {

61:     function transferFrom(address from, address to, uint256 amount) public override returns (bool) {

71:     function _validateTransfer(address from, address to) internal view {

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

```solidity
File: ./contracts/interfaces/IERC677Receiver.sol

9:     function onTokenTransfer(address sender, uint value, bytes calldata data) external;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/interfaces/IERC677Receiver.sol)

### <a name="NC-10"></a>[NC-10] Change int to int256
Throughout the code base, some variables are declared as `int`. To favor explicitness, consider changing all instances of `int` to `int256`

*Instances (2)*:
```solidity
File: ./contracts/Titn.sol

24:         lzEndpoint = _lzEndpoint;

83:             to != lzEndpoint // Allow transfers to LayerZero endpoint

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-11"></a>[NC-11] Change uint to uint256
Throughout the code base, some variables are declared as `uint`. To favor explicitness, consider changing all instances of `uint` to `uint256`

*Instances (1)*:
```solidity
File: ./contracts/interfaces/IERC677Receiver.sol

9:     function onTokenTransfer(address sender, uint value, bytes calldata data) external;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/interfaces/IERC677Receiver.sol)

### <a name="NC-12"></a>[NC-12] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (3)*:
```solidity
File: ./contracts/MergeTgt.sol

167:     function setLockedStatus(LockedStatus newStatus) external onlyOwner {
             lockedStatus = newStatus;
             emit LockedStatusUpdated(newStatus);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

33:     function setTransferAllowedContract(address _transferAllowedContract) external onlyOwner {
            transferAllowedContract = _transferAllowedContract;
            emit TransferAllowedContractUpdated(_transferAllowedContract);

43:     function setBridgedTokenTransferLocked(bool _isLocked) external onlyOwner {
            isBridgedTokensTransferLocked = _isLocked;
            emit BridgedTokenTransferLockUpdated(_isLocked);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-13"></a>[NC-13] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (9)*:
```solidity
File: ./contracts/MergeTgt.sol

44:     function deposit(IERC20 token, uint256 amount) external onlyOwner {

96:     function claimTitn(uint256 amount) external nonReentrant {

114:     function withdrawRemainingTitn() external nonReentrant {

167:     function setLockedStatus(LockedStatus newStatus) external onlyOwner {

172:     function setLaunchTime() external onlyOwner {

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

33:     function setTransferAllowedContract(address _transferAllowedContract) external onlyOwner {

43:     function setBridgedTokenTransferLocked(bool _isLocked) external onlyOwner {

56:     function transfer(address to, uint256 amount) public override returns (bool) {

61:     function transferFrom(address from, address to, uint256 amount) public override returns (bool) {

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-14"></a>[NC-14] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (2)*:
```solidity
File: ./contracts/MergeTgt.sol

58:     /// @notice Withdraw any locked contracts in Merge contract
        function withdraw(IERC20 token, uint256 amount) external onlyOwner {

64:     /// @notice tgt token transferAndCall ERC677-like
        function onTokenTransfer(address from, uint256 amount, bytes calldata extraData) external nonReentrant {

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="NC-15"></a>[NC-15] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (2)*:
```solidity
File: ./contracts/MergeTgt.sol

66:         if (msg.sender != address(tgt)) {

97:         require(amount <= claimableTitnPerUser[msg.sender], "Not enough claimable titn");

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="NC-16"></a>[NC-16] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (3)*:
```solidity
File: ./contracts/MergeTgt.sol

21:     mapping(address => uint256) public claimedTitnPerUser;

22:     mapping(address => uint256) public claimableTitnPerUser;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

9:     mapping(address => bool) public isBridgedTokenHolder;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-17"></a>[NC-17] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (1)*:
```solidity
File: ./contracts/Titn.sol

89:     /**
         * @dev Credits tokens to the specified address.
         * @param _to The address to credit the tokens to.
         * @param _amountLD The amount of tokens to credit in local decimals.
         * @dev _srcEid The source chain ID.
         * @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
         */
        function _credit(
            address _to,
            uint256 _amountLD,
            uint32 /*_srcEid*/
        ) internal virtual override returns (uint256 amountReceivedLD) {
            if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)
            // Default OFT mints on dst.
            _mint(_to, _amountLD);
    
            // Addresses that bridged tokens have some transfer restrictions
            if (!isBridgedTokenHolder[_to]) {
                isBridgedTokenHolder[_to] = true;
            }
    
            // In the case of NON-default OFT, the _amountLD MIGHT not be == amountReceivedLD.
            return _amountLD;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-18"></a>[NC-18] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (9)*:
```solidity
File: ./contracts/MergeTgt.sol

46:             revert InvalidTokenReceived();

51:             revert InvalidAmountReceived();

67:             revert InvalidTokenReceived();

70:             revert MergeLocked();

73:             revert ZeroAmount();

76:             revert MergeEnded();

100:             revert TooLateToClaimRemainingTitn();

118:             revert TooEarlyToClaimRemainingTitn();

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

85:             revert BridgedTokensTransferLocked();

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-19"></a>[NC-19] Use scientific notation (e.g. `1e18`) rather than exponentiation (e.g. `10**18`)
While this won't save gas in the recent solidity versions, this is shorter and more readable (this is especially true in calculations).

*Instances (2)*:
```solidity
File: ./contracts/MergeTgt.sol

17:     uint256 public constant TGT_TO_EXCHANGE = 579_000_000 * 10 ** 18; // 57.9% of MAX_TGT

18:     uint256 public constant TITN_ARB = 173_700_000 * 10 ** 18; // 17.37% of MAX_TITN

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="NC-20"></a>[NC-20] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (1)*:
```solidity
File: ./contracts/Titn.sol

1: 
   Current order:
   VariableDeclaration.isBridgedTokenHolder
   VariableDeclaration.isBridgedTokensTransferLocked
   VariableDeclaration.transferAllowedContract
   VariableDeclaration.lzEndpoint
   ErrorDefinition.BridgedTokensTransferLocked
   FunctionDefinition.constructor
   EventDefinition.TransferAllowedContractUpdated
   FunctionDefinition.setTransferAllowedContract
   FunctionDefinition.getTransferAllowedContract
   EventDefinition.BridgedTokenTransferLockUpdated
   FunctionDefinition.setBridgedTokenTransferLocked
   FunctionDefinition.getBridgedTokenTransferLocked
   FunctionDefinition.transfer
   FunctionDefinition.transferFrom
   FunctionDefinition._validateTransfer
   FunctionDefinition._credit
   
   Suggested order:
   VariableDeclaration.isBridgedTokenHolder
   VariableDeclaration.isBridgedTokensTransferLocked
   VariableDeclaration.transferAllowedContract
   VariableDeclaration.lzEndpoint
   ErrorDefinition.BridgedTokensTransferLocked
   EventDefinition.TransferAllowedContractUpdated
   EventDefinition.BridgedTokenTransferLockUpdated
   FunctionDefinition.constructor
   FunctionDefinition.setTransferAllowedContract
   FunctionDefinition.getTransferAllowedContract
   FunctionDefinition.setBridgedTokenTransferLocked
   FunctionDefinition.getBridgedTokenTransferLocked
   FunctionDefinition.transfer
   FunctionDefinition.transferFrom
   FunctionDefinition._validateTransfer
   FunctionDefinition._credit

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-21"></a>[NC-21] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (1)*:
```solidity
File: ./contracts/Titn.sol

73:         uint256 arbitrumChainId = 42161;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-22"></a>[NC-22] Internal and private variables and functions names should begin with an underscore
According to the Solidity Style Guide, Non-`external` variable and function names should begin with an [underscore](https://docs.soliditylang.org/en/latest/style-guide.html#underscore-prefix-for-non-external-functions-and-variables)

*Instances (2)*:
```solidity
File: ./contracts/Titn.sol

10:     bool private isBridgedTokensTransferLocked;

12:     address private lzEndpoint;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="NC-23"></a>[NC-23] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (8)*:
```solidity
File: ./contracts/MergeTgt.sol

31:     event Deposit(address indexed token, uint256 amount);

32:     event Withdraw(address indexed token, uint256 amount, address indexed to);

33:     event LaunchTimeSet(uint256 timestamp);

34:     event LockedStatusUpdated(LockedStatus newStatus);

35:     event ClaimTitn(address indexed user, uint256 amount);

36:     event ClaimableTitnUpdated(address indexed user, uint256 titnOut);

37:     event WithdrawRemainingTitn(address indexed user, uint256 amount);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

42:     event BridgedTokenTransferLockUpdated(bool isLocked);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 1 |
| [L-2](#L-2) | Some tokens may revert when zero value transfers are made | 4 |
| [L-3](#L-3) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [L-4](#L-4) | Division by zero not prevented | 2 |
| [L-5](#L-5) | Prevent accidentally burning tokens | 2 |
| [L-6](#L-6) | Possible rounding issue | 1 |
| [L-7](#L-7) | Loss of precision | 2 |
| [L-8](#L-8) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 2 |
| [L-9](#L-9) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 2 |
| [L-10](#L-10) | File allows a version of solidity that is susceptible to an assembly optimizer bug | 1 |
| [L-11](#L-11) | Unsafe ERC20 operation(s) | 2 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (1)*:
```solidity
File: ./contracts/MergeTgt.sol

11: contract MergeTgt is IMerge, Ownable, ReentrancyGuard {

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="L-2"></a>[L-2] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (4)*:
```solidity
File: ./contracts/MergeTgt.sol

54:         token.safeTransferFrom(msg.sender, address(this), amount);

60:         token.safeTransfer(owner(), amount);

109:         titn.safeTransfer(msg.sender, amount);

148:         titn.safeTransfer(msg.sender, titnOut);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="L-3"></a>[L-3] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: ./contracts/Titn.sol

24:         lzEndpoint = _lzEndpoint;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="L-4"></a>[L-4] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (2)*:
```solidity
File: ./contracts/MergeTgt.sol

136:         uint256 userProportionalShare = (claimableTitn * unclaimedTitn) / initialTotalClaimable;

161:             titnAmount = (tgtAmount * TITN_ARB * remainingtime) / (TGT_TO_EXCHANGE * 270 days); //270 days = 9 months

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="L-5"></a>[L-5] Prevent accidentally burning tokens
Minting and burning tokens to address(0) prevention

*Instances (2)*:
```solidity
File: ./contracts/Titn.sol

23:         _mint(msg.sender, initialMintAmount);

103:         _mint(_to, _amountLD);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="L-6"></a>[L-6] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (1)*:
```solidity
File: ./contracts/MergeTgt.sol

136:         uint256 userProportionalShare = (claimableTitn * unclaimedTitn) / initialTotalClaimable;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="L-7"></a>[L-7] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (2)*:
```solidity
File: ./contracts/MergeTgt.sol

158:             titnAmount = (tgtAmount * TITN_ARB) / TGT_TO_EXCHANGE;

161:             titnAmount = (tgtAmount * TITN_ARB * remainingtime) / (TGT_TO_EXCHANGE * 270 days); //270 days = 9 months

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="L-8"></a>[L-8] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (2)*:
```solidity
File: ./contracts/MergeTgt.sol

2: pragma solidity ^0.8.9;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

2: pragma solidity ^0.8.22;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="L-9"></a>[L-9] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
Use [Ownable2Step.transferOwnership](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol) which is safer. Use it as it is more secure due to 2-stage ownership transfer.

**Recommended Mitigation Steps**

Use <a href="https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol">Ownable2Step.sol</a>
  
  ```solidity
      function acceptOwnership() external {
          address sender = _msgSender();
          require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
          _transferOwnership(sender);
      }
```

*Instances (2)*:
```solidity
File: ./contracts/MergeTgt.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

4: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

### <a name="L-10"></a>[L-10] File allows a version of solidity that is susceptible to an assembly optimizer bug
In solidity versions 0.8.13 and 0.8.14, there is an [optimizer bug](https://github.com/ethereum/solidity-blog/blob/499ab8abc19391be7b7b34f88953a067029a5b45/_posts/2022-06-15-inline-assembly-memory-side-effects-bug.md) where, if the use of a variable is in a separate `assembly` block from the block in which it was stored, the `mstore` operation is optimized out, leading to uninitialized memory. The code currently does not have such a pattern of execution, but it does use `mstore`s in `assembly` blocks, so it is a risk for future changes. The affected solidity versions should be avoided if at all possible.

*Instances (1)*:
```solidity
File: ./contracts/MergeTgt.sol

2: pragma solidity ^0.8.9;

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="L-11"></a>[L-11] Unsafe ERC20 operation(s)

*Instances (2)*:
```solidity
File: ./contracts/Titn.sol

58:         return super.transfer(to, amount);

63:         return super.transferFrom(from, to, amount);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 1 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 9 |
### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (1)*:
```solidity
File: ./contracts/MergeTgt.sol

54:         token.safeTransferFrom(msg.sender, address(this), amount);

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (9)*:
```solidity
File: ./contracts/MergeTgt.sol

11: contract MergeTgt is IMerge, Ownable, ReentrancyGuard {

39:     constructor(address _tgt, address _titn, address initialOwner) Ownable(initialOwner) {

44:     function deposit(IERC20 token, uint256 amount) external onlyOwner {

59:     function withdraw(IERC20 token, uint256 amount) external onlyOwner {

167:     function setLockedStatus(LockedStatus newStatus) external onlyOwner {

172:     function setLaunchTime() external onlyOwner {

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/MergeTgt.sol)

```solidity
File: ./contracts/Titn.sol

22:     ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_delegate) {

33:     function setTransferAllowedContract(address _transferAllowedContract) external onlyOwner {

43:     function setBridgedTokenTransferLocked(bool _isLocked) external onlyOwner {

```
[Link to code](https://github.com/code-423n4/2025-02-thorwallet/blob/main/./contracts/Titn.sol)

